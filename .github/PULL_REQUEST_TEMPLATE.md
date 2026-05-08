## Summary

<!-- What does this PR change and why? -->

## Type

- [ ] feat
- [ ] fix
- [ ] chore / docs / refactor / test

## Checklist

- [ ] `shellcheck install.sh` passes
- [ ] `bash -n install.sh` passes
- [ ] Smoke install tested with `HOME=$(mktemp -d) ./install.sh`
- [ ] Tested on macOS **and** Linux (or noted why one is N/A)
- [ ] `CHANGELOG.md` updated under `Unreleased`
- [ ] No credentials, hostnames, or personal paths in the diff

## Threat-model impact

<!-- Does this change what the skill persists, executes, or confirms? If yes, describe. If no, write "none". -->
