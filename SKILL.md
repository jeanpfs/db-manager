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
allowed-tools: Bash(psql *), Bash(pg_dump *), Bash(source *), Bash(grep *), Bash(echo *), Read, Grep, Glob, Write, Edit
---

# DB Manager — PostgreSQL Direct Access

## Session status

!`SESSION_FILE="/tmp/.db_session_$(echo "$PWD" | md5 -q 2>/dev/null || echo "$PWD" | md5sum | cut -c1-8)"; if [ -f "$SESSION_FILE" ]; then source "$SESSION_FILE"; echo "CONNECTED: ${DB_LABEL} (source: ${DB_SOURCE})"; else echo "NO_SESSION"; fi`

## Core principle

Use `source .env && psql "$DATABASE_URL"` — nothing more. Credentials stay in project `.env` files, session lives in `/tmp` (volatile).

## Session setup (only if NO_SESSION)

1. Find `.env` files with `DATABASE_URL` in the project:

```bash
find . \( -name ".env" -o -name ".env.local" -o -name ".env.development" -o -name ".env.dev" \
  -o -name ".env.staging" -o -name ".env.production" \) \
  -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null | while read -r f; do
  match=$(grep -E "^(DATABASE_URL|DB_URL|POSTGRES_URL)" "$f" 2>/dev/null | head -1)
  [ -n "$match" ] && echo "$f"
done
```

2. If multiple found, ask which one. If only one, use it.

3. Save session and test:

```bash
ENV_PATH="<selected .env>"
PROJECT=$(basename "$PWD" | tr -cd 'a-zA-Z0-9._-')
SESSION_FILE="/tmp/.db_session_$(echo "$PWD" | md5 -q 2>/dev/null || echo "$PWD" | md5sum | cut -c1-8)"
DB_URL=$(grep -E "^(DATABASE_URL|DB_URL|POSTGRES_URL)" "$ENV_PATH" | head -1 | cut -d= -f2- | sed "s/^[\"']\|[\"']$//g")

(umask 077; cat > "$SESSION_FILE" << EOF
DATABASE_URL=${DB_URL}
DB_LABEL=${PROJECT}/<label>
DB_SOURCE=${ENV_PATH}
EOF
)

source "$SESSION_FILE"
psql "$DATABASE_URL" -c "SELECT 1" > /dev/null 2>&1 && echo "Connected: ${DB_LABEL}" || echo "FAILED"
```

## Running queries

```bash
source "$SESSION_FILE" && psql "$DATABASE_URL" -c "SELECT ..."
```

## Query protocol — MANDATORY

**NEVER guess column names.** Before writing any SELECT, INSERT, UPDATE, or DELETE:

1. Run `\d tablename` for each table involved
2. Only then write SQL using the actual column names

**Exceptions:**
- Table already inspected earlier in the same conversation
- User provides the exact SQL to run

## Destructive operations

For destructive operations (DELETE, UPDATE, DROP, TRUNCATE, etc.), follow the mandatory confirmation protocol in [security-rules.md](references/security-rules.md). **Never skip confirmation.**

## Schema dump (opt-in)

Only when the user explicitly asks:

```bash
source "$SESSION_FILE"
mkdir -p docs
pg_dump "$DATABASE_URL" --schema-only --no-owner --no-acl --no-comments > docs/schema.sql
```
