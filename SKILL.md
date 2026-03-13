---
name: db-manager
description: >
  Use when the user asks to query a database, run SQL, check tables, inspect schema,
  connect to PostgreSQL, switch database environments, or any task involving database
  access (SELECT, INSERT, UPDATE, DELETE, pg_dump, psql). Also use when starting a
  session in a project that has .env files with DATABASE_URL. Triggers: "query the
  database", "run this SQL", "show me the tables", "check the schema", "connect to
  the database", "switch to staging/production", "roda esse SQL", "consulta o banco",
  "mostra as tabelas", "acessa o banco".
argument-hint: "[SQL query or command]"
allowed-tools: Bash, Read, Grep, Glob, Write, Edit
---

# DB Manager — PostgreSQL Direct Access

## Session status

!`SESSION_FILE="/tmp/.db_session_$(echo "$PWD" | md5 -q 2>/dev/null || echo "$PWD" | md5sum | cut -c1-8)"; if [ -f "$SESSION_FILE" ]; then source "$SESSION_FILE"; echo "CONNECTED: ${DB_LABEL} (source: ${DB_SOURCE})"; else echo "NO_SESSION"; fi`

## Core principles

- Credentials stay in each project's `.env` files — nothing is duplicated
- `~/.claude/db-map.json` stores **only paths**, never credentials
- Active connection lives only in `/tmp` — volatile, gone on reboot
- Destructive operations require strict explicit confirmation before execution

## Dependencies

Requires `psql`, `pg_dump`, and `jq`. Install with `brew install postgresql jq` or `apt install postgresql-client jq`.

## Session setup

If the session status above shows `NO_SESSION`, follow the full setup procedure in [session-setup.md](references/session-setup.md).

If already connected, proceed directly to queries.

## Helper script

The helper script at `${CLAUDE_SKILL_DIR}/scripts/db` wraps `psql` with automatic session loading. Install it to `~/.claude/scripts/db`:

```bash
cp "${CLAUDE_SKILL_DIR}/scripts/db" ~/.claude/scripts/db
chmod +x ~/.claude/scripts/db
```

Usage: `~/.claude/scripts/db -c "SELECT * FROM users LIMIT 5"`

## Query protocol — MANDATORY before writing any SQL

**NEVER guess column names.** Before writing any SELECT, INSERT, UPDATE, or DELETE:

1. **Identify which tables** will be referenced in the query
2. **Run `\d tablename`** for each table to get the real columns
3. **Only then** write the SQL using the actual column names from step 2

```bash
source "$SESSION_FILE"
psql "$DATABASE_URL" -c "\d tablename"
```

**Exceptions:**
- If you already ran `\d tablename` earlier in the same conversation for the same table, reuse that information
- If the user provides the exact SQL to run, execute it as-is without schema checking

## Security rules

For destructive operations (DELETE, UPDATE, DROP, TRUNCATE, etc.), follow the mandatory confirmation protocol in [security-rules.md](references/security-rules.md). **Never skip confirmation.**

## Generate/update schema

Schema dump is **opt-in** — run only when the user explicitly asks or on first-time project setup:

```bash
source "$SESSION_FILE"
mkdir -p docs
pg_dump "$DATABASE_URL" --schema-only --no-owner --no-acl --no-comments > docs/schema.sql
LABEL=$(grep DB_LABEL "$SESSION_FILE" | cut -d= -f2)
echo "Schema generated from: $LABEL — $(grep -c '^CREATE TABLE' docs/schema.sql) tables"
```

## Update project CLAUDE.md

Before adding, check if a database section already exists. If it does, merge rather than duplicate.

```markdown
## Database (PostgreSQL)

**Access**: `~/.claude/scripts/db -c "SQL"` — never use MCP
**Schema**: `docs/schema.sql` — reflects the active session connection
**Switch environment**: ask Claude for a new session setup
**Connection map**: `~/.claude/db-map.json` (paths only, no credentials)

### Examples
- `~/.claude/scripts/db -c "\dt"` — list tables
- `~/.claude/scripts/db -c "\d users"` — inspect table structure
- `~/.claude/scripts/db -c "SELECT id, name FROM users LIMIT 10"`
- `~/.claude/scripts/db < queries/debug.sql`
```

## Checklists

### First-time (per project, once)
- [ ] Project `.env` paths registered in `~/.claude/db-map.json`
- [ ] `~/.claude/scripts/db` helper installed
- [ ] `docs/schema.sql` generated (if requested)
- [ ] `CLAUDE.md` updated (merged, not overwritten)

### Per-session
- [ ] Session setup completed (or existing session confirmed)
- [ ] Connection test passed
- [ ] Table list cached

### Per-query
- [ ] Identified tables involved in the query
- [ ] Ran `\d tablename` for each table (or reused from earlier in conversation)
- [ ] Query uses ONLY real column names from `\d` output
