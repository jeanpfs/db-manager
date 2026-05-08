# Security Rules for Destructive Operations

## Query classification

**SAFE** — execute directly:
- `SELECT` (read-only)
- `EXPLAIN` (without `ANALYZE`)
- `\dt`, `\d`, `\dn`, `\l` and other psql meta-commands
- `pg_dump --schema-only`

**REQUIRE STRICT CONFIRMATION** — never execute without explicit approval:
- `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, `MERGE`, `UPSERT`
- `EXPLAIN ANALYZE` (it executes the underlying statement)
- `DROP TABLE`, `DROP SCHEMA`, `DROP DATABASE`, `DROP INDEX`, `DROP FUNCTION`, `DROP TRIGGER`
- `CREATE TABLE`, `CREATE INDEX`, `CREATE OR REPLACE FUNCTION`, `CREATE TRIGGER`
- `ALTER` (any form)
- `GRANT`, `REVOKE`, `ALTER DEFAULT PRIVILEGES`
- `COPY ... FROM`, `COPY ... TO PROGRAM`
- `VACUUM FULL`, `REINDEX`, `CLUSTER`, `REFRESH MATERIALIZED VIEW`
- `CALL`, `DO` (anonymous code blocks)
- Any auto-generated query that modifies data or schema

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

Path: `${HOME}/.cache/db-manager/audit_$(echo "$PWD" | shasum -a 256 | cut -c1-16).log` (mode `600`)

```
[<timestamp>] DESTRUCTIVE OPERATION EXECUTED
Environment : <DB_LABEL>
Query       : <exact query>
Rows        : <result>
Confirmed by: <CONFIRM or CONFIRM PRODUCTION>
```

## Security model summary

| What leaks if...                       | Impact                                              |
|----------------------------------------|-----------------------------------------------------|
| `~/.cache/db-manager/session_*` leaks  | Project label and `.env` path (no credentials)      |
| `~/.cache/db-manager/audit_*.log` leaks| Past destructive queries and labels (no credentials)|
| `.env.staging` leaks                   | Credentials for that environment (pre-existing risk)|
| `docs/schema.sql` leaks                | Database structure, no data                         |

The real risk remains the `.env` files themselves — which existed before this skill.
