nix_shell := if env('IN_NIX_SHELL', '') != '' { '' } else { 'nix develop -c' }
name := "devbox"

# List available recipes
default:
    @just --list

# --- Lifecycle ---

# We build the Lima template from our locked `nixos-lima` flake input
# via `.#lima-template`, so `limactl start` sees exactly the pinned
# version (qcow2 digest included) instead of refetching master.

# Create and start the NixOS VM, then apply our custom config
[group('lifecycle')]
start vm=name:
    {{nix_shell}} limactl start --name={{vm}} --cpus=6 --memory=12 --disk=100 --yes $(nix build --no-link --print-out-paths .#lima-template)
    just provision {{vm}}

# `--workdir /tmp` keeps CWD off Lima's Users-<user> 9p mount so that
# switch-to-configuration can restart that mount unit cleanly.
# `--impure` + `env USER=...` lets default.nix read $USER across the sudo
# boundary, so the flake provisions for the invoking user.

# Apply our NixOS + home-manager config inside the VM (idempotent)
[group('lifecycle')]
provision vm=name:
    {{nix_shell}} limactl shell --workdir /tmp {{vm}} -- sudo env USER=$USER nixos-rebuild switch --impure --flake $(pwd)#devbox

# Stop the VM
[group('lifecycle')]
stop vm=name:
    {{nix_shell}} limactl stop {{vm}}

# Remove the VM (destructive)
[group('lifecycle')]
delete vm=name:
    {{nix_shell}} limactl delete {{vm}}

# List all Lima VMs
[group('lifecycle')]
list:
    {{nix_shell}} limactl list

# --- Access ---

# Open a shell in the VM
[group('access')]
shell vm=name:
    {{nix_shell}} limactl shell {{vm}}

# Print Lima's generated SSH config for the VM
[group('access')]
ssh-config vm=name:
    {{nix_shell}} limactl show-ssh --format=config {{vm}}

# SSH into the VM using Lima's generated config (no global config mutation)
[group('access')]
ssh *args='':
    ssh -F ~/.lima/{{name}}/ssh.config lima-{{name}} {{args}}
