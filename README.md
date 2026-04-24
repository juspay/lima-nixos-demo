# devbox

NixOS based devbox on macOS — a [`justfile`](justfile) + flake that boots and provisions a customized NixOS VM via [Lima](https://lima-vm.io/).

## Requirements

- [Nix](https://nixos.asia/en/install) (everything else comes from the devShell)
- [`just`](https://github.com/casey/just)

Run `nix develop` once to enter a shell with `lima`, `just`, and `gh` pinned, or let each recipe invoke `nix develop -c` automatically.

## Usage

```sh
just              # list recipes
just start        # create + boot the VM from the latest release image
just start dev    # create + boot the VM from the mutable dev release image
just shell        # open a shell in the VM
just stop         # stop the VM
just delete       # remove the VM
just recreate     # wipe and start fresh
just list         # list all Lima VMs
```

First `just start` downloads and boots the latest `juspay/devbox` GitHub release template. That template keeps the locked `nixos-lima` defaults for mounts, memory, and port forwarding, and points at the matching devbox qcow2 assets with SHA-512 digests.

The VM name is `devbox`, and the guest user defaults to your macOS `$USER`. CPU / memory / disk default to `host cores − 2`, `host RAM − 4 GiB`, and `half of host free disk`. Memory is a ceiling (the vz driver demand-pages from the host); disk is a ceiling (Lima's qcow2 is sparse and grows lazily); CPU over-subscription is cheap. Override any default with `just --set`, e.g. `just --set cpus 4 --set memory 16 --set disk 200 start`.

## What's in the VM

Via [`nixos/devbox.nix`](nixos/devbox.nix): `nix-ld`, flakes, [`nixos-vscode-server`](https://github.com/nix-community/nixos-vscode-server), `starship`, `direnv` + `nix-direnv`, `btop`, `just`, `gh`.

## Release images

The flake can build baked Lima-compatible qcow2 images from `nixosConfigurations.devbox-aarch64.config.system.build.images.qemu-efi` and `nixosConfigurations.devbox-x86_64.config.system.build.images.qemu-efi`. Publishing a GitHub release triggers the release-image workflow, which builds the images, stages them as Actions artifacts, then uploads `devbox-<tag>-aarch64.qcow2`, `devbox-<tag>-x86_64.qcow2`, matching SHA-512 files, and `devbox-lima.yaml` to that release.

`just start` uses `https://github.com/juspay/devbox/releases/latest/download/devbox-lima.yaml`; `just start dev` uses `https://github.com/juspay/devbox/releases/download/dev/devbox-lima.yaml`.

## Cutting a release

After merging release-image changes, create a GitHub release:

```sh
just release v0.1.0
```

Publishing the release starts the `Release Images` workflow. The workflow builds and compresses the x86_64 image on the self-hosted `x86_64-linux` runner and the aarch64 image on GitHub's `ubuntu-24.04-arm` runner, then uploads the qcow2, SHA-512, and Lima template assets to the release.

For PR testing, use the mutable dev prerelease:

```sh
just release-development
```

That recreates the `dev` release at the current branch and dispatches the image workflow on that branch. Its assets are overwritten on each run, so use it only for disposable testing.

## Security model

This is a local, single-user devbox VM, not a hardened multi-user host. The passwordless sudo behavior comes from `nixos-lima`: `lima-init` creates a guest user matching your macOS `$USER` and adds it to `wheel`, while the `nixos-lima` module sets `security.sudo.wheelNeedsPassword = false`. This repo currently keeps that behavior.

SSH access uses Lima's generated config under `~/.lima/devbox/ssh.config`, so this repo does not mutate your global `~/.ssh/config`. Your macOS home is mounted into the guest at `/Users/<you>` read-only; keep day-to-day development work in the guest's own writable filesystem, such as `~/code`.

## Installing more tools

For ad hoc user-level tools inside the VM, use `nix profile install`, e.g. `nix profile install nixpkgs#ripgrep`.

For declarative user packages, dotfile management, and systemd user services, use Home Manager from the [`juspay/nixos-unified-template`](https://github.com/juspay/nixos-unified-template).

## SSH access

```sh
just ssh                # SSH into the VM (uses Lima's generated config, no global mutation)
just ssh uname -a       # run a command over SSH
just ssh-config         # print Lima's generated SSH config
```

## VSCode Remote-SSH

Point VSCode at Lima's generated SSH config — no `~/.ssh/config` mutation, no tunnel service:

1. `Cmd-Shift-P` → **Remote-SSH: Settings** → set **Config File** to `~/.lima/devbox/ssh.config`.
2. `Cmd-Shift-P` → **Remote-SSH: Connect to Host…** → pick `lima-devbox`.

That's the whole setup. Subsequent connects are one command.

## Working on projects inside the VM

Lima mounts your macOS home at `/Users/<you>` inside the guest **read-only**. For development, clone repos into the guest's own filesystem (writable, faster, no 9p overhead):

```sh
just ssh
mkdir -p ~/code && cd ~/code
git clone …
```

The mount's read-only state is the Lima default; we keep it. If you want to override it (or anything else in the template), [`flake.nix`](flake.nix) has a `yq`-based pattern commented next to the `lima-template` derivation.
