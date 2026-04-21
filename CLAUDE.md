# Notes for Claude

## Keep docs in sync

When changing `justfile`, `flake.nix`, `nixos/`, or `home/`, update [README.md](README.md) in the same change if it affects:

- Recipe names, defaults, or the first-run flow.
- What's installed in the VM (system or user packages).
- Host-side requirements or one-time setup.
- Constraints users hit in practice (e.g. the read-only `/Users/<you>` mount).

Docs drift silently — prefer a one-line README tweak over "I'll get to it later".
