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
---

# DB Manager — PostgreSQL Direct Access

## Core principles
- Credentials stay in each project's `.env` files. Nothing is duplicated.
- `~/.claude/db-map.json` stores **only paths**, never credentials.
- Active connection lives only in `/tmp` — volatile, gone on reboot.
- Destructive operations require strict explicit confirmation before execution.

---

## Dependencies

```bash
which psql    || echo "install: brew install postgresql / apt install postgresql-client"
which pg_dump || echo "same package as psql"
which jq      || echo "install: brew install jq / apt install jq"
```

---

## Central map: `~/.claude/db-map.json`

Stores only file paths, zero credentials:
```json
{
  "${PROJECT}": {
    "local":   "/path/to/${PROJECT}/.env",
    "staging": "/path/to/${PROJECT}/.env.staging"
  }
}
```

If this file leaks: only project names and file paths are exposed — no usernames, passwords, or hosts.

---

## Session Setup (run at the start of every session)

### Step 1 — Identify current project
```bash
PROJECT=$(basename "$PWD" | tr -cd 'a-zA-Z0-9._-')
SESSION_FILE="/tmp/.db_session_$(echo "$PWD" | md5 -q 2>/dev/null || echo "$PWD" | md5sum | cut -c1-8)"
```

### Step 2 — Find available connections

**A) Entries in db-map.json for this project:**
```bash
MAP_FILE="$HOME/.claude/db-map.json"
if [ -f "$MAP_FILE" ]; then
  jq -r --arg proj "$PROJECT" '
    to_entries[] |
    select(.key | test($proj; "i")) |
    .key as $pname |
    .value | to_entries[] |
    "\($pname)/\(.key): \(.value)"
  ' "$MAP_FILE" 2>/dev/null | while IFS= read -r line; do
    envpath=$(echo "$line" | sed 's/.*: //')
    status="NOT FOUND"; [ -f "$envpath" ] && status="found"
    echo "$line [$status]"
  done
else
  echo "MAP_EMPTY"
fi
```

**B) Fallback — detect .env files in current project (works for monorepos):**
```bash
find . \( -name ".env" -o -name ".env.local" -o -name ".env.development" -o -name ".env.dev" \
  -o -name ".env.staging" -o -name ".env.production" \) \
  -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null | while read -r f; do
  match=$(grep -E "^(DATABASE_URL|DB_URL|POSTGRES_URL)" "$f" 2>/dev/null | head -1)
  [ -n "$match" ] && echo "$f"
done
```

### Step 3 — Present options and ask

Show all discovered connections numbered, plus a manual entry option.
Ask: **"Which connection should be used for this session?"**

### Step 4 — Load credentials and save session to /tmp
```bash
ENV_PATH="<selected .env path>"
DB_URL=$(grep -E "^(DATABASE_URL|DB_URL|POSTGRES_URL)" "$ENV_PATH" | head -1 | cut -d= -f2- | sed 's/^["'\'']\|["'\''"]$//g')

(umask 077; cat > "$SESSION_FILE" << EOF
DATABASE_URL=${DB_URL}
DB_LABEL=${PROJECT}/<selected-label>
DB_SOURCE=${ENV_PATH}
EOF
)
```

### Step 5 — Lock session file and test connection
```bash
chmod 600 "$SESSION_FILE"
source "$SESSION_FILE"
psql "$DATABASE_URL" -c "SELECT 1" > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "Connection verified: ${DB_LABEL} (source: ${DB_SOURCE})"
else
  echo "Connection FAILED. Check credentials in ${DB_SOURCE}"
  rm -f "$SESSION_FILE"
  exit 1
fi
```

---

## `~/.claude/scripts/db` helper script

Create at `~/.claude/scripts/db` if it doesn't exist (global, no repo pollution):

```bash
mkdir -p ~/.claude/scripts
cat > ~/.claude/scripts/db << 'SCRIPT'
#!/bin/bash
SESSION_FILE="/tmp/.db_session_$(echo "$PWD" | md5 -q 2>/dev/null || echo "$PWD" | md5sum | cut -c1-8)"

if [ -f "$SESSION_FILE" ]; then
  if [ "$(stat -f %Op "$SESSION_FILE" 2>/dev/null || stat -c %a "$SESSION_FILE")" != "600" ]; then
    echo "Session file has unsafe permissions. Run: chmod 600 $SESSION_FILE" >&2
    exit 1
  fi
  if grep -qvE '^(DATABASE_URL|DB_LABEL|DB_SOURCE)=' "$SESSION_FILE"; then
    echo "Session file contains unexpected content. Refusing to load." >&2
    exit 1
  fi
  source "$SESSION_FILE"
fi

if [ -z "$DATABASE_URL" ]; then
  for f in .env .env.local .env.development .env.dev; do
    if [ -f "$f" ]; then
      val=$(grep -E "^(DATABASE_URL|DB_URL|POSTGRES_URL)" "$f" | head -1 | cut -d= -f2- | sed 's/^["'\'']\|["'\''"]$//g')
      [ -n "$val" ] && export DATABASE_URL="$val" && break
    fi
  done
fi

if [ -z "$DATABASE_URL" ]; then
  echo "No connection configured. Ask Claude: 'set up the database for this session'"
  exit 1
fi

LABEL=$(grep DB_LABEL "$SESSION_FILE" 2>/dev/null | cut -d= -f2 || echo "fallback .env")
echo "[db] $LABEL" >&2
export PGDATABASE="$DATABASE_URL"
psql "$@"
SCRIPT
chmod +x ~/.claude/scripts/db
```

Usage: `~/.claude/scripts/db -c "SELECT * FROM users LIMIT 5"`

---

## Register project in db-map.json

After detecting the project's .env files, offer to register them:

```bash
MAP_FILE="$HOME/.claude/db-map.json"
[ ! -f "$MAP_FILE" ] && echo '{}' > "$MAP_FILE"

jq --arg proj "$PROJECT" \
   --arg local "$LOCAL_ENV_PATH" \
   --arg staging "$STAGING_ENV_PATH" \
   '.[$proj] = {local: $local, staging: $staging}' \
   "$MAP_FILE" > "${MAP_FILE}.tmp" && mv "${MAP_FILE}.tmp" "$MAP_FILE"
```

Always ask the user before saving. Only include environments that actually exist.

---

## Generate/update schema

Schema dump is **opt-in** — run only when the user explicitly asks or on first-time project setup:
```bash
source "$SESSION_FILE"
mkdir -p docs
pg_dump "$DATABASE_URL" --schema-only --no-owner --no-acl --no-comments > docs/schema.sql
LABEL=$(grep DB_LABEL "$SESSION_FILE" | cut -d= -f2)
echo "Schema generated from: $LABEL — $(grep -c '^CREATE TABLE' docs/schema.sql) tables"
```

Also regenerate when the user switches environments.

---

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

---

## Security rules for destructive operations

### Query classification

**SAFE** — execute directly:
- `SELECT`, `EXPLAIN`, `EXPLAIN ANALYZE`
- `\dt`, `\d`, `\dn`, `\l` and other psql meta-commands
- `pg_dump --schema-only`

**REQUIRE STRICT CONFIRMATION** — never execute without explicit approval:
- `DELETE`, `UPDATE`, `TRUNCATE`
- `DROP TABLE`, `DROP SCHEMA`, `DROP DATABASE`, `DROP INDEX`
- `ALTER TABLE ... DROP COLUMN`, `ALTER TABLE ... RENAME`, `ALTER TABLE ... ALTER COLUMN ... TYPE`
- `GRANT`, `REVOKE`, `ALTER DEFAULT PRIVILEGES`
- Bulk `INSERT` (more than 50 records or `INSERT` without explicit `VALUES`)
- Any auto-generated query that modifies data

---

### Mandatory confirmation protocol

Before executing any destructive operation, ALWAYS print this block:

```
╔══════════════════════════════════════════════════════════════╗
║   ⚠️  DESTRUCTIVE OPERATION — CONFIRMATION REQUIRED  ⚠️      ║
╠══════════════════════════════════════════════════════════════╣
║  Environment : <DB_LABEL from session>                      ║
║  Operation   : <operation type>                             ║
║  Impact      : irreversible — data will be permanently lost ║
╠══════════════════════════════════════════════════════════════╣
║  Query to be executed:                                      ║
║                                                             ║
║    <exact query>                                            ║
║                                                             ║
╠══════════════════════════════════════════════════════════════╣
║  Rows affected (estimate): <count>                          ║
║  (ran: SELECT COUNT(*) with the same condition)             ║
╚══════════════════════════════════════════════════════════════╝

  Type exactly  CONFIRM  to proceed, or anything else to cancel:
```

**Protocol rules:**
- Never shorten or simplify this block
- Always show the exact query — no summaries or paraphrasing
- Always run a `SELECT COUNT(*)` with the same `WHERE` condition first and show the row count
- If the environment is `staging` or `production`, add an extra warning line:
  ```
  ║  🔴 WARNING: you are connected to STAGING / PRODUCTION      ║
  ```
- Wait for the user to type literally `CONFIRM` (uppercase) — do not accept "yes", "y", "ok", "sure" or any variation
- If the user types anything other than `CONFIRM`, cancel and acknowledge the cancellation

---

### Extra protection for production

If `DB_LABEL` contains `prod` or `production`, replace the confirmation block with:

```
╔══════════════════════════════════════════════════════════════╗
║   🔴🔴🔴  PRODUCTION — ADDITIONAL LOCK ACTIVE  🔴🔴🔴        ║
╠══════════════════════════════════════════════════════════════╣
║  This operation targets the PRODUCTION database.            ║
║  Damage here affects real users immediately.                ║
╠══════════════════════════════════════════════════════════════╣
║  Query to be executed:                                      ║
║                                                             ║
║    <exact query>                                            ║
║                                                             ║
╠══════════════════════════════════════════════════════════════╣
║  Rows affected (estimate): <count>                          ║
╠══════════════════════════════════════════════════════════════╣
║  To proceed you must:                                       ║
║  1. Confirm you have a recent backup                        ║
║  2. Type exactly:  CONFIRM PRODUCTION                       ║
╚══════════════════════════════════════════════════════════════╝
```

Wait for the user to type literally `CONFIRM PRODUCTION`.

---

### Audit log

After every confirmed destructive operation, append to the audit log (created with `umask 077` to restrict access):

Path: `/tmp/.db_audit_$(echo "$PWD" | md5 -q 2>/dev/null || echo "$PWD" | md5sum | cut -c1-8).log`

```
[<timestamp>] DESTRUCTIVE OPERATION EXECUTED
Environment : <DB_LABEL>
Query       : <exact query>
Rows        : <result>
Confirmed by: <CONFIRM or CONFIRM PRODUCTION>
```

---

## Security model summary

| What leaks if...              | Impact                                          |
|-------------------------------|-------------------------------------------------|
| `~/.claude/db-map.json` leaks | Only project names and file paths               |
| `/tmp/.db_session_*` leaks    | Active session URL (gone on reboot)             |
| `.env.staging` leaks          | Credentials for that environment (pre-existing risk) |
| `docs/schema.sql` leaks       | Database structure, no data                     |

The real risk remains the `.env` files themselves — which existed before this skill.

---

## Installation

```bash
cp -r db-manager ~/.claude/skills/
```

---

## First-time checklist (per project, once)

- [ ] Project `.env` paths registered in `~/.claude/db-map.json`
- [ ] `~/.claude/scripts/db` helper created
- [ ] `docs/schema.sql` generated (if requested)
- [ ] `CLAUDE.md` updated (merged, not overwritten)

## Per-session checklist

- [ ] Session setup completed
- [ ] Connection test passed
- [ ] Schema regenerated if environment changed

---

## Token strategy

| Approach              | Tokens per operation                     |
|-----------------------|------------------------------------------|
| MCP postgres          | ~2,000–5,000 (schema always injected)    |
| `db -c` direct        | ~50–100                                  |
| `docs/schema.sql`     | Read on demand only                      |
