# lima-nixos-demo

A [`justfile`](justfile) + flake for running a customized NixOS devbox VM via [Lima](https://lima-vm.io/) on macOS.

## Requirements

- [Nix](https://nixos.asia/en/install) (everything else comes from the devShell)
- [`just`](https://github.com/casey/just)

Run `nix develop` once to enter a shell with `lima` + `just` pinned, or let each recipe invoke `nix develop -c` automatically.

## Usage

```sh
just              # list recipes
just start        # create + boot the VM, then apply our flake (nixos-rebuild)
just provision    # re-apply the flake (after editing config)
just shell        # open a shell in the VM
just stop         # stop the VM
just delete       # remove the VM
just list         # list all Lima VMs
```

First `just start` takes a few minutes: it boots the stock `github:nixos-lima` image, then `nixos-rebuild switch` applies our [`flake.nix`](flake.nix) on top (system + home-manager in one shot).

The VM user and hostname default to your macOS `$USER` / `devbox`.

## What's in the VM

System (via [`nixos/configuration.nix`](nixos/configuration.nix)): `nix-ld`, flakes, passwordless `wheel` sudo, `systemd-logind` lingering for the user, [`nixos-vscode-server`](https://github.com/nix-community/nixos-vscode-server).

User (via [`home/home.nix`](home/home.nix)): `starship`, `direnv` + `nix-direnv`, `btop`, `gh`.

## SSH access

```sh
just ssh                # SSH into the VM (uses Lima's generated config, no global mutation)
just ssh uname -a       # run a command over SSH
just ssh-config         # print Lima's generated SSH config
```

## Working on projects inside the VM

Lima mounts your macOS home at `/Users/<you>` inside the guest **read-only**. For development, clone repos into the guest's own filesystem (writable, faster, no 9p overhead):

```sh
just ssh
mkdir -p ~/code && cd ~/code
git clone …
```

The mount's read-only state is the Lima default; we keep it. If you want to override it (or anything else in the template), [`flake.nix`](flake.nix) has a `yq`-based pattern commented next to the `lima-template` derivation.
