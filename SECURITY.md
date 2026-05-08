# Security Policy

## Supported versions

Only the latest released minor version receives security fixes.

## Reporting a vulnerability

**Do not open a public GitHub issue for security reports.**

Email the maintainer at **jean.pfs2@gmail.com** with:

- A description of the issue and the impact you believe it has
- Steps to reproduce, including the OS, shell, and PostgreSQL client versions
- A suggested fix if you have one

You should receive an acknowledgement within 5 business days. Once the issue is confirmed and a fix is ready, the vulnerability will be disclosed publicly along with the patched release.

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
