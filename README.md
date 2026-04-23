# devbox

NixOS based devbox on macOS via [Lima](https://lima-vm.io/).

The host only needs `limactl` and `just`. Nix runs inside the VM:

- A temporary builder VM builds a local qcow2 image from this flake.
- The working VM boots directly from that local image.
- User Home Manager state is not baked into the image.
- [`home/home.nix`](home/home.nix) stays user-editable on the host and is applied explicitly with `just home-switch`.

## Requirements

- [`limactl`](https://lima-vm.io/)
- [`just`](https://github.com/casey/just)

No host-side Nix install is required for normal use.

## Usage

```sh
just              # list recipes
just build-image  # build/update the local qcow2 via a temporary builder VM
just start        # boot the working VM from the local qcow2
just home-switch  # apply home/home.nix inside the running VM
just shell        # open a shell in the VM
just stop         # stop the VM
just delete       # remove the VM
just recreate     # delete and recreate the VM from the current local qcow2
just list         # list all Lima VMs
```

`just start` will automatically run `just build-image` first if the local qcow2 is missing.

Image artifacts live outside `~/.lima` by default, under `~/Library/Caches/devbox`. This matters because Lima treats directories under `~/.lima` as instance state.

## What Lives Where

System image:

- Defined by [`nixos/configuration.nix`](nixos/configuration.nix)
- Built inside a temporary Lima builder VM
- Includes `home-manager`, `git`, `just`, `direnv`, `nix-direnv`, `starship`, and the rest of the machine-level setup

User home config:

- Defined by [`home/home.nix`](home/home.nix)
- Not baked into the qcow2
- Applied on demand with `just home-switch`
- Uses the guest's current `$USER` and `$HOME` during activation

## Working on Projects

The working VM mounts only:

- This repo, read-only
- `~/Shared/devbox-exchange`, writable

It does not mount your full macOS home by default.

That means:

- Edit [`home/home.nix`](home/home.nix) on the host
- Run `just home-switch` when you want to apply it
- Keep active repos inside the guest filesystem, for example `~/code`
- Use `~/Shared/devbox-exchange` only for intentional file transfer

Example:

```sh
just start
just home-switch
just ssh mkdir -p ~/code
just ssh 'cd ~/code && git clone ...'
```

## Refreshing Changes

After editing [`nixos/configuration.nix`](nixos/configuration.nix):

```sh
just build-image
just recreate
```

After editing [`home/home.nix`](home/home.nix):

```sh
just home-switch
```

If you already have an older VM from the previous workflow, run `just recreate` once to pick up the new mount defaults and local-image boot flow.

If you tested an earlier revision of this repo and see Lima errors mentioning `devbox-artifacts/lima.yaml`, remove the stale directory once:

```sh
rm -rf ~/.lima/devbox-artifacts
```

## SSH Access

```sh
just ssh
just ssh uname -a
just ssh-config
```

## VSCode Remote-SSH

Point VSCode at Lima's generated SSH config:

1. `Cmd-Shift-P` → **Remote-SSH: Settings** → set **Config File** to `~/.lima/devbox/ssh.config`
2. `Cmd-Shift-P` → **Remote-SSH: Connect to Host…** → pick `lima-devbox`

## Security Posture

The default workflow is designed to avoid ambient host-secret exposure:

- no full-`HOME` mount
- no host-side Nix requirement
- only a narrow repo mount plus a single exchange directory

So credentials in host paths like `~/.aws`, `~/.ssh`, and `~/.config` are not exposed to the working VM unless you deliberately broaden the mount set.
