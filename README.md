# db-manager

A Claude Code skill for safe PostgreSQL access from project `.env` files.

The skill auto-detects `DATABASE_URL` in your project's `.env` files, lets the agent run `psql` against the right environment, and gates destructive operations behind an explicit confirmation protocol.

## Features

- Auto-discovers `.env`, `.env.local`, `.env.development`, `.env.staging`, `.env.production` with `DATABASE_URL` / `DB_URL` / `POSTGRES_URL`
- Per-project session keyed by working directory, stored under `~/.cache/db-manager/` with mode `600`
- Session file holds **only** the path to the `.env` and a label — never the URL itself
- Mandatory schema inspection (`\d`) before generating SQL
- Strict confirmation block for any mutation (`INSERT`, `UPDATE`, `DELETE`, `DROP`, `ALTER`, `EXPLAIN ANALYZE`, etc.)
- Extra `CONFIRM PRODUCTION` lock when the label contains `prod`
- Audit log of every confirmed destructive operation

## Install

```bash
git clone https://github.com/<your-user>/db-manager.git
cd db-manager
./install.sh
```

This copies `SKILL.md`, `LICENSE`, `README.md` and `references/` into `~/.claude/skills/db-manager/`. Existing installs are moved to a timestamped backup, never deleted.

## Usage

In Claude Code, ask any database question, for example:

```
mostra as tabelas
run SELECT count(*) from users
quais usuários cadastraram nas últimas 24h?
```

The skill will:

1. Look for `.env` files with a database URL.
2. Ask you which environment to use (or pick the only one).
3. Save session metadata under `~/.cache/db-manager/session_<hash>` (mode `600`).
4. Run `\d` on the relevant tables before writing SQL.
5. Run the query.

For mutations, the skill prints a confirmation block including the exact SQL and a `SELECT COUNT(*)` estimate, and waits for you to type `CONFIRM` (or `CONFIRM PRODUCTION` for production).

## Threat model

What this skill **protects against**:

- Agent-generated mutations executing without explicit human approval
- Hallucinated column names producing silently wrong queries
- Accidental writes to production when intending to hit dev
- Persisting credentials in long-lived files outside the project

What it **does not protect against**:

- A compromised `.env` file in the project (pre-existing risk; same as any local dev)
- Local users on the same machine reading the project's `.env`
- Connection URIs visible in `/proc/<pid>/cmdline` on Linux while `psql` is running. For higher assurance use `~/.pgpass` (mode `600`) and pass host/db/user instead of the full URL
- Malicious modifications to the `.env` content itself — the skill treats the URL as data, not code, but a tampered `.env` could still point `psql` at a hostile server

## Files written by the skill

| Path | Mode | Contents |
|------|------|----------|
| `~/.cache/db-manager/session_<hash>` | `600` | Path to the project `.env`, label, source — **no URL** |
| `~/.cache/db-manager/audit_<hash>.log` | `600` | Timestamped log of confirmed destructive operations |
| `docs/schema.sql` (only on explicit request) | repo-default | `pg_dump --schema-only`, no data |

## Uninstall

```bash
rm -rf ~/.claude/skills/db-manager
rm -rf ~/.cache/db-manager
```

## License

MIT — see [LICENSE](./LICENSE).
