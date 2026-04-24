# devbox

NixOS based devbox on macOS — a [`justfile`](justfile) + flake that boots and provisions a customized NixOS VM via [Lima](https://lima-vm.io/).

## Requirements

- [Nix](https://nixos.asia/en/install) (everything else comes from the devShell)
- [`just`](https://github.com/casey/just)

Run `nix develop` once to enter a shell with `lima`, `just`, and `gh` pinned, or let each recipe invoke `nix develop -c` automatically.

If you only want to run the published devbox image, you do not need Nix or this repository. See [Non-Nix users](#non-nix-users).

## Non-Nix users

You can use the published devbox image with Lima only. You do not need Nix or this repository.

Install Lima first. On macOS with Homebrew:

```sh
brew install lima
```

For MacPorts, binary archives, or other hosts, see the [Lima installation docs](https://lima-vm.io/docs/installation/).

Launch devbox:

```sh
curl -fsSL https://juspay.github.io/devbox/start | sh -
```

The script creates `/tmp/lima-devbox`, sizes CPU / memory / disk from your host, starts the latest published release image, and prints the next commands. If `devbox` is already running, it says so and leaves it alone. If the VM exists but is stopped, it starts it. If the image is not cached yet, Lima downloads it.

Open a shell:

```sh
limactl shell --workdir=. devbox
```

Use `--workdir=.` because devbox does not mount your macOS home directory. Plain `limactl shell devbox` makes Lima try to enter your macOS current directory inside the guest when any host mount exists, and that path is intentionally unavailable.

To customize the launch:

```sh
curl -fsSL https://juspay.github.io/devbox/start | sh -s -- --help
curl -fsSL https://juspay.github.io/devbox/start | sh -s -- --tag <tag>
curl -fsSL https://juspay.github.io/devbox/start | sh -s -- --cpus 8 --memory 16 --disk 200
```

Clone projects inside the VM:

```sh
mkdir -p ~/code && cd ~/code
git clone …
```

Move files intentionally through the scratch directory:

```sh
# On macOS:
cp ./some-file /tmp/lima-devbox/

# Inside devbox:
cp /tmp/lima-devbox/some-file .
```

To stop or delete the VM:

```sh
limactl stop devbox
limactl delete devbox
```

If you prefer not to pipe a script into `sh`, download it first:

```sh
curl -fsSLO https://juspay.github.io/devbox/start
sh start --help
sh start
```

Or call Lima directly:

```sh
tag=<tag>
limactl start --name=devbox "https://github.com/juspay/devbox/releases/download/$tag/devbox-lima.yaml"
```

## Usage

```sh
just              # list recipes
just start        # create + boot the VM from the latest release image
just start dev    # create + boot the VM from the mutable dev release image
just shell        # open a shell in the VM, starting in the guest home
just stop         # stop the VM
just delete       # remove the VM
just delete-downloaded-images dev # clear cached Lima image downloads for dev
just recreate     # wipe and start fresh
just list         # list all Lima VMs
```

First `just start` downloads and boots the latest `juspay/devbox` GitHub release template. That template keeps the locked `nixos-lima` integration defaults, points at the matching devbox qcow2 assets with SHA-512 digests, and mounts only `/tmp/lima-devbox` from the host for intentional file transfer.

The VM name is `devbox`, and the guest user defaults to your macOS `$USER`. CPU / memory / disk default to `host cores − 2`, `host RAM − 4 GiB`, and `half of host free disk`. Memory is a ceiling (the vz driver demand-pages from the host); disk is a ceiling (Lima's qcow2 is sparse and grows lazily); CPU over-subscription is cheap. Override any default with `just --set`, e.g. `just --set cpus 4 --set memory 16 --set disk 200 start`.

## What's in the VM

Via [`nixos/devbox.nix`](nixos/devbox.nix): `nix-ld`, flakes, [`nixos-vscode-server`](https://github.com/nix-community/nixos-vscode-server), `starship`, `direnv` + `nix-direnv`, `btop`, `just`, `gh`.

## Release images

The flake can build baked Lima-compatible qcow2 images from `nixosConfigurations.devbox-aarch64.config.system.build.images.qemu-efi` and `nixosConfigurations.devbox-x86_64.config.system.build.images.qemu-efi`. Publishing a GitHub release triggers the release-image workflow, which uploads `devbox-<tag>-aarch64.qcow2`, `devbox-<tag>-x86_64.qcow2`, matching SHA-512 files, and `devbox-lima.yaml` to that release.

`just start` uses `https://github.com/juspay/devbox/releases/latest/download/devbox-lima.yaml`; `just start dev` uses `https://github.com/juspay/devbox/releases/download/dev/devbox-lima.yaml`.

Because the `dev` release is mutable, `just recreate dev` clears matching Lima image cache entries before starting. Tagged releases keep Lima's normal download cache.

## Cutting a release

After merging release-image changes, create a GitHub release:

```sh
just release v0.1.0
```

`just release` generates release notes from Conventional Commits since the latest tag, creates the GitHub release, and starts the `Release Images` workflow. The workflow builds and compresses the x86_64 image on the self-hosted `x86_64-linux` runner and the aarch64 image on GitHub's `ubuntu-24.04-arm` runner, then uploads the qcow2, SHA-512, and Lima template assets to the release.

To preview the generated notes:

```sh
just release-notes v0.1.1
```

For PR testing, use the mutable dev prerelease:

```sh
just release-development
```

That recreates the `dev` release at the current branch and dispatches the image workflow on that branch. Its assets are overwritten on each run, so use it only for disposable testing.

## Conventional Commits

This repo uses squash merges, so PR titles should follow Conventional Commits. The merged commit title becomes the release-note input.

Use types like `feat`, `fix`, `docs`, `ci`, `build`, `refactor`, `test`, and `chore`, with an optional scope:

```text
feat: boot devbox from release image
fix(lima): clear mutable dev image cache
docs: document release workflow
```

## Security model

This is a local, single-user devbox VM, not a hardened multi-user host. The passwordless sudo behavior comes from `nixos-lima`: `lima-init` creates a guest user matching your macOS `$USER` and adds it to `wheel`, while the `nixos-lima` module sets `security.sudo.wheelNeedsPassword = false`. This repo currently keeps that behavior.

SSH access uses Lima's generated config under `~/.lima/devbox/ssh.config`, so this repo does not mutate your global `~/.ssh/config`. The VM does not mount your macOS home directory. The only default host mount is `/tmp/lima-devbox`, mounted writable at the same path in the guest so you can intentionally transfer files across the boundary. Treat it as a scratch exchange directory, not a workspace or secrets store.

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

For development, clone repos into the guest's own filesystem (writable, faster, no 9p overhead):

```sh
just ssh
mkdir -p ~/code && cd ~/code
git clone …
```

To move files between macOS and the VM, use `/tmp/lima-devbox` on either side. It is the only default host path exposed to the guest.
