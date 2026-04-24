# Notes for Codex

## Keep docs in sync

When changing `justfile`, `flake.nix`, `nixos/`, or `home/`, update [README.md](README.md) in the same change if it affects:

- Recipe names, defaults, or the first-run flow.
- What's installed in the VM (system or user packages).
- Host-side requirements or one-time setup.
- Constraints users hit in practice (e.g. the read-only `/Users/<you>` mount).

Docs drift silently — prefer a one-line README tweak over "I'll get to it later".

## Conventional Commits

Use Conventional Commit titles for commits and pull requests. This repo uses
squash merges, so the PR title becomes the commit title and release-note input.

Examples:

- `feat: boot devbox from release image`
- `fix(lima): clear mutable dev image cache`
- `docs: document release workflow`
