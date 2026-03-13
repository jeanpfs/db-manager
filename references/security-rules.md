# Security Rules for Destructive Operations

## Query classification

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

## Mandatory confirmation protocol

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

## Extra protection for production

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

## Audit log

After every confirmed destructive operation, append to the audit log (created with `umask 077`):

Path: `/tmp/.db_audit_$(echo "$PWD" | md5 -q 2>/dev/null || echo "$PWD" | md5sum | cut -c1-8).log`

```
[<timestamp>] DESTRUCTIVE OPERATION EXECUTED
Environment : <DB_LABEL>
Query       : <exact query>
Rows        : <result>
Confirmed by: <CONFIRM or CONFIRM PRODUCTION>
```

## Security model summary

| What leaks if...              | Impact                                              |
|-------------------------------|-----------------------------------------------------|
| `~/.claude/db-map.json` leaks | Only project names and file paths                   |
| `/tmp/.db_session_*` leaks    | Active session URL (gone on reboot)                 |
| `.env.staging` leaks          | Credentials for that environment (pre-existing risk)|
| `docs/schema.sql` leaks       | Database structure, no data                         |

The real risk remains the `.env` files themselves — which existed before this skill.
