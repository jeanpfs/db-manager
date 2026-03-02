# Design: Subagent Query Delegation

**Data:** 2026-03-02
**Status:** Aprovado

## Problema

O db-manager skill atual executa tudo no contexto principal do Claude:
- Inspeção de schema (`\d tablename`) polui o contexto com dados estruturais
- Resultados de SELECT grandes acumulam tokens
- Overhead repetitivo (schema check antes de cada query)

Resultado: conversas ficam pesadas e consomem tokens desnecessariamente.

## Solução

Delegar toda execução de queries para subagents via Agent tool do Claude Code.

### Abordagem escolhida: Subagent Único por Query

Cada operação de banco spawna um subagent `general-purpose` que:
1. Recebe a pergunta em linguagem natural + contexto de conexão
2. Inspeciona schema autonomamente
3. Monta e executa SQL
4. Retorna apenas o resultado resumido

## Arquitetura

### Divisão de responsabilidades

| Responsabilidade | Onde roda |
|---|---|
| Session setup (detectar projeto, carregar .env, testar conexão) | **Principal** |
| Cache de tabelas (Step 6) | **Principal** |
| Confirmação de operações destrutivas | **Principal** |
| Registro no projeto (db-map.json, CLAUDE.md) | **Principal** |
| Inspeção de schema (`\d tablename`) | **Subagent** |
| Montagem de SQL | **Subagent** |
| Execução de SELECT/EXPLAIN | **Subagent** |
| Formatação/resumo de resultados | **Subagent** |

### Fluxo geral

```
Usuário pede algo sobre o banco
        ↓
Agente principal (skill db-manager)
        ↓
  Session setup (se necessário)
        ↓
  Spawna subagent via Agent tool
  - subagent_type: "general-purpose"
  - prompt: template com contexto de conexão + pergunta do usuário
        ↓
  Subagent executa autonomamente:
    1. Lê /tmp/.db_tables_* pra saber as tabelas
    2. Roda \d nas tabelas relevantes
    3. Monta e executa o SQL
    4. Retorna resultado formatado
        ↓
  Agente principal recebe resultado resumido
  Apresenta ao usuário de forma concisa
```

### Prompt template do subagent

```
Você é um assistente de banco de dados PostgreSQL.

## Contexto
- Session file: /tmp/.db_session_<hash>
- Tabelas disponíveis: <lista de /tmp/.db_tables_*>
- Helper script: ~/.claude/scripts/db

## Tarefa
<pergunta do usuário em linguagem natural>

## Protocolo obrigatório
1. Para cada tabela que será referenciada, rode: ~/.claude/scripts/db -c "\d tablename"
2. Use SOMENTE colunas reais retornadas pelo \d
3. Monte e execute o SQL via: ~/.claude/scripts/db -c "<sql>"
4. Se a query retornar mais de 20 linhas, resuma os dados (totais, padrões, amostra)

## Operações destrutivas
Se o SQL envolve DELETE, UPDATE, DROP, TRUNCATE, ALTER:
- NÃO execute
- Retorne: o SQL proposto, estimativa de rows afetadas (via SELECT COUNT), e o motivo
- O agente principal fará a confirmação com o usuário

## Formato de resposta
Retorne APENAS:
- O SQL executado (ou proposto, se destrutivo)
- O resultado (resumido se necessário)
- Observações relevantes (se houver)
NÃO inclua explicações longas sobre o que você fez.
```

### Fluxo para operações destrutivas

```
Subagent recebe: "delete os usuários inativos há mais de 1 ano"
        ↓
  Roda \d users → descobre colunas
  Monta: DELETE FROM users WHERE last_active_at < NOW() - INTERVAL '1 year'
  Roda: SELECT COUNT(*) FROM users WHERE last_active_at < NOW() - INTERVAL '1 year'
  → Resultado: 47 rows
        ↓
  Retorna pro principal:
    SQL: DELETE FROM users WHERE ...
    Rows afetadas: ~47
    Motivo: usuários sem atividade há mais de 1 ano
        ↓
Agente principal mostra ao usuário + pede CONFIRM
        ↓
Se confirmado: principal executa direto via db -c
```

## Mudanças no SKILL.md

1. **Nova seção "Subagent Protocol"** — substitui parte do "Query Protocol"
2. **"Query Protocol" simplificado** — protocolo de `\d` se move pro prompt do subagent
3. **Checklist per-query atualizada** — subagent cuida de schema/SQL, principal verifica coerência
4. **Seção de destrutivas** — adiciona fluxo "receber proposta do subagent → confirmar → executar"
5. **Token Strategy atualizada:**
   - Antes: schema + query + resultado = ~500-5000 tokens no contexto principal
   - Depois: só resultado resumido = ~50-200 tokens no contexto principal

## Error handling

- Se o subagent falhar (timeout, erro de conexão): fallback para execução direta (comportamento atual)
- Se o subagent retornar resultado incoerente: re-spawnar ou executar direto

## Decisões de design

- **Model:** herda do principal (não forçar haiku) — manter qualidade em queries complexas
- **Autonomia total:** subagent recebe linguagem natural e resolve sozinho
- **Destrutivas no principal:** subagent prepara SQL + estimativa, confirmação fica no principal
- **Session setup no principal:** envolve interação com usuário (escolha de ambiente)
