# Contributing

Thanks for your interest in improving `db-manager`.

## Development setup

```bash
git clone https://github.com/jeanpfs/db-manager.git
cd db-manager
```

There is no build step. The skill is plain Markdown plus a Bash installer.

## Before submitting a PR

1. **Lint shell scripts:** `shellcheck install.sh` (and any new `.sh` files).
2. **Syntax check:** `bash -n install.sh`.
3. **Run a smoke install** into a throwaway `HOME`:

   ```bash
   HOME=$(mktemp -d) ./install.sh
   ls "$HOME/.claude/skills/db-manager/"
   ```

4. **Test on both macOS and Linux** when changes touch shell snippets — `sha256sum` and `shasum` are not interchangeable across platforms.
5. **Update `CHANGELOG.md`** under the `Unreleased` section.
6. **Do not** add comments to shell scripts unless the *why* is non-obvious; prefer self-explanatory names.

## Commit style

[Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`.

## Branching

Use Gitflow prefixes: `feature/<slug>`, `bugfix/<slug>`, `chore/<slug>`, `docs/<slug>`. English kebab-case slugs only.

## Reporting bugs

Use the issue templates in `.github/ISSUE_TEMPLATE/`. Include OS, shell, PostgreSQL client version, and reproducible steps.

## Reporting security issues

See [SECURITY.md](./SECURITY.md). Do **not** open public issues for vulnerabilities.

## Code of Conduct

This project follows the [Contributor Covenant](./CODE_OF_CONDUCT.md).
