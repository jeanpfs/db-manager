# Security Policy

## Supported versions

Only the latest released minor version receives security fixes.

## Reporting a vulnerability

**Do not open a public GitHub issue for security reports.**

Use GitHub's private **Report a vulnerability** form (Security tab > Advisories), or email the maintainer at **jean.pfs2@gmail.com** with:

- A description of the issue and the impact you believe it has
- Steps to reproduce, including the OS, shell, and PostgreSQL client versions
- A suggested fix if you have one

You should receive an acknowledgement within 5 business days. Once the issue is confirmed and a fix is ready, the vulnerability will be disclosed publicly along with the patched release.

## Credentials handling

The skill reads database credentials from the project's `.env` files on every query. It must **never** log, print, echo, or persist any of the following, in chat output, error messages, audit logs, session files, or shell traces (`set -x`):

- The contents of `.env` files, or the full value of `DATABASE_URL` / `DB_URL` / `POSTGRES_URL`
- Passwords, tokens, or API keys, including a `PGPASSWORD` value
- Connection strings with embedded credentials (only variable names, or host/database with the password masked, may be shown)
- Query results that expose secrets (e.g. password hashes, API keys)

Session files and the audit log store metadata only (labels, queries, timestamps), with mode `600`. A change that causes any of the above to be printed or written to disk is a vulnerability: report it privately.

## Scope

In scope:

- Shell injection or command execution via `SKILL.md` snippets, `install.sh`, or session files
- Credentials persisted to disk in plaintext outside the user's `.env`
- Privilege escalation through the install script
- Bypass of the destructive-operation confirmation protocol

Out of scope:

- Vulnerabilities in PostgreSQL itself, `psql`, `pg_dump`, or Claude Code
- Risks already documented in the README's threat model (e.g. argv exposure of `psql` URI on Linux)
- Compromise of the user's `.env` files, which is a pre-existing risk
