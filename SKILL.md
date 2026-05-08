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
allowed-tools: Bash(psql *), Bash(pg_dump *), Bash(grep *), Bash(echo *), Bash(printf *), Bash(mkdir *), Bash(chmod *), Bash(test *), Bash(shasum *), Bash(sha256sum *), Bash(find *), Bash(cut *), Bash(head *), Bash(basename *), Bash(tr *), Bash(sed *), Bash(date *), Bash(install *), Read, Grep, Glob, Write, Edit
---

# DB Manager — PostgreSQL Direct Access

## Session status

!`SESSION_DIR="${HOME}/.cache/db-manager"; if command -v sha256sum >/dev/null 2>&1; then SESSION_KEY=$(printf %s "$PWD" | sha256sum | cut -c1-16); else SESSION_KEY=$(printf %s "$PWD" | shasum -a 256 | cut -c1-16); fi; SESSION_FILE="${SESSION_DIR}/session_${SESSION_KEY}"; if [ -f "$SESSION_FILE" ] && [ ! -L "$SESSION_FILE" ]; then DB_LABEL=$(grep '^DB_LABEL=' "$SESSION_FILE" | cut -d= -f2-); DB_SOURCE=$(grep '^DB_SOURCE=' "$SESSION_FILE" | cut -d= -f2-); echo "CONNECTED: ${DB_LABEL} (source: ${DB_SOURCE})"; else echo "NO_SESSION"; fi`

> Hash helper used throughout: `sha256sum` on Linux, `shasum -a 256` on macOS — both produce the same hex digest, the snippets fall back automatically.

## Core principle

Read `DATABASE_URL` from project `.env` files only when needed. The session file stores **only metadata** (path to the `.env` and a label) — never the URL itself. Never `source` the session file: it is data, not code.

## Session setup (only if NO_SESSION)

1. Find `.env` files with `DATABASE_URL` in the project:

```bash
find . \( -name ".env" -o -name ".env.local" -o -name ".env.development" -o -name ".env.dev" \
  -o -name ".env.staging" -o -name ".env.production" \) \
  -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null | while read -r f; do
  match=$(grep -E "^(DATABASE_URL|DB_URL|POSTGRES_URL)=" "$f" 2>/dev/null | head -1)
  [ -n "$match" ] && echo "$f"
done
```

2. If multiple found, ask the user which one. If only one, use it.

3. Save session metadata under `~/.cache/db-manager/` (mode `600`):

```bash
ENV_PATH="<selected .env>"
PROJECT=$(basename "$PWD" | tr -cd 'a-zA-Z0-9._-')
LABEL_SUFFIX="<dev|staging|production|...>"

SESSION_DIR="${HOME}/.cache/db-manager"
mkdir -p "$SESSION_DIR" && chmod 700 "$SESSION_DIR"

if command -v sha256sum >/dev/null 2>&1; then
  SESSION_KEY=$(printf %s "$PWD" | sha256sum | cut -c1-16)
else
  SESSION_KEY=$(printf %s "$PWD" | shasum -a 256 | cut -c1-16)
fi
SESSION_FILE="${SESSION_DIR}/session_${SESSION_KEY}"

if [ -L "$SESSION_FILE" ]; then
  echo "REFUSING: session path is a symlink"; exit 1
fi

umask 077
{
  printf 'DB_ENV_PATH=%s\n' "$ENV_PATH"
  printf 'DB_LABEL=%s/%s\n' "$PROJECT" "$LABEL_SUFFIX"
  printf 'DB_SOURCE=%s\n' "$ENV_PATH"
} > "$SESSION_FILE"
chmod 600 "$SESSION_FILE"
```

4. Test the connection without persisting the URL:

```bash
DB_URL=$(grep -E "^(DATABASE_URL|DB_URL|POSTGRES_URL)=" "$ENV_PATH" | head -1 | cut -d= -f2-)
DB_URL="${DB_URL%\"}"; DB_URL="${DB_URL#\"}"
DB_URL="${DB_URL%\'}"; DB_URL="${DB_URL#\'}"

psql "$DB_URL" -c "SELECT 1" >/dev/null 2>&1 && echo "Connected" || echo "FAILED"
```

## Running queries

Re-read the URL from the `.env` referenced by the session every time — never persist it:

```bash
SESSION_DIR="${HOME}/.cache/db-manager"
if command -v sha256sum >/dev/null 2>&1; then
  SESSION_KEY=$(printf %s "$PWD" | sha256sum | cut -c1-16)
else
  SESSION_KEY=$(printf %s "$PWD" | shasum -a 256 | cut -c1-16)
fi
SESSION_FILE="${SESSION_DIR}/session_${SESSION_KEY}"

ENV_PATH=$(grep '^DB_ENV_PATH=' "$SESSION_FILE" | cut -d= -f2-)
DB_URL=$(grep -E "^(DATABASE_URL|DB_URL|POSTGRES_URL)=" "$ENV_PATH" | head -1 | cut -d= -f2-)
DB_URL="${DB_URL%\"}"; DB_URL="${DB_URL#\"}"
DB_URL="${DB_URL%\'}"; DB_URL="${DB_URL#\'}"

psql "$DB_URL" -c "SELECT ..."
```

> Note on argv exposure: PostgreSQL connection URIs as the first positional argument to `psql` may be visible in `/proc/<pid>/cmdline` on Linux while the process runs. For higher assurance, configure `~/.pgpass` (mode `600`) and pass only host/db/user instead of the full URL.

## Query protocol — MANDATORY

**NEVER guess column names.** Before writing any SELECT, INSERT, UPDATE, or DELETE:

1. Run `\d tablename` for each table involved
2. Only then write SQL using the actual column names

**Exceptions:**
- Table already inspected earlier in the same conversation
- User provides the exact SQL to run

## Destructive operations

For destructive operations, follow the mandatory confirmation protocol in [security-rules.md](references/security-rules.md). **Never skip confirmation.**

## Schema dump (opt-in)

Only when the user explicitly asks:

```bash
ENV_PATH=$(grep '^DB_ENV_PATH=' "$SESSION_FILE" | cut -d= -f2-)
DB_URL=$(grep -E "^(DATABASE_URL|DB_URL|POSTGRES_URL)=" "$ENV_PATH" | head -1 | cut -d= -f2-)
DB_URL="${DB_URL%\"}"; DB_URL="${DB_URL#\"}"
DB_URL="${DB_URL%\'}"; DB_URL="${DB_URL#\'}"
mkdir -p docs
pg_dump "$DB_URL" --schema-only --no-owner --no-acl --no-comments > docs/schema.sql
```

## Managing the session

Switch to a different `.env` for the same project:

```bash
# Re-run the "Session setup" steps with a different ENV_PATH; the file is
# overwritten in place under ~/.cache/db-manager/.
```

Forget the current session:

```bash
SESSION_DIR="${HOME}/.cache/db-manager"
if command -v sha256sum >/dev/null 2>&1; then
  SESSION_KEY=$(printf %s "$PWD" | sha256sum | cut -c1-16)
else
  SESSION_KEY=$(printf %s "$PWD" | shasum -a 256 | cut -c1-16)
fi
rm -f "${SESSION_DIR}/session_${SESSION_KEY}"
```

Forget all sessions:

```bash
rm -rf "${HOME}/.cache/db-manager"
```
