# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.1] - 2026-10-16

### Added

- skills.sh metadata: `metadata.json` and the `license` frontmatter field.
- YAML issue forms (bug report, feature request) and Dependabot for GitHub Actions.
- Credentials-handling section in `SECURITY.md`.
- Tag-driven release workflow that publishes GitHub releases with notes taken from this changelog.

### Changed

- Remaining Portuguese strings translated to English.
- CI shellcheck now covers every tracked shell script; workflow permissions limited to `contents: read`.
- Author identity standardized across project metadata.

## [0.1.0] - 2026-05-08

### Added

- Initial public release of the `db-manager` Claude Code skill.
- Auto-discovery of `.env` files containing `DATABASE_URL` / `DB_URL` / `POSTGRES_URL`.
- Per-project sessions stored under `~/.cache/db-manager/` (mode `600`); session metadata only — credentials are re-read from the project `.env` on every query.
- Mandatory schema inspection (`\d`) before generating SQL.
- Strict confirmation protocol for destructive operations (`INSERT`, `UPDATE`, `DELETE`, `DROP`, `ALTER`, `EXPLAIN ANALYZE`, etc.) with extra `CONFIRM PRODUCTION` lock for production-labeled sessions.
- Audit log of confirmed destructive operations.
- `install.sh` with whitelisted file copy, atomic staging, symlink rejection, and timestamped backup of previous installs.
- Cross-platform shell snippets (`sha256sum` on Linux, `shasum -a 256` on macOS).
- README with threat model, requirements, troubleshooting, and uninstall instructions.
- `SECURITY.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`.
- GitHub Actions CI running `shellcheck` and a smoke install on `ubuntu-latest` and `macos-latest`.

[Unreleased]: https://github.com/jeanpfs/db-manager/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/jeanpfs/db-manager/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/jeanpfs/db-manager/releases/tag/v0.1.0
