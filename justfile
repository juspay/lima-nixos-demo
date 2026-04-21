nix_shell := if env('IN_NIX_SHELL', '') != '' { '' } else { 'nix develop -c' }
name := "devbox"

# CPUs = host logical cores − 2 (leave a couple for the host). CPU
# over-subscription is cheap — the host scheduler time-slices — so we
# can be generous. Override: `just --set cpus 4 start`.
cpus := `echo $(( $(sysctl -n hw.ncpu) - 2 ))`

# Memory ceiling in GiB = host RAM − 4 GiB. With the vz driver the host
# demand-pages guest memory, so this is a cap, not an up-front allocation.
# Override: `just --set memory 16 start`.
memory := `echo $(( $(sysctl -n hw.memsize) / 1073741824 - 4 ))`

# Disk ceiling in GiB = half of host root-fs free space. Lima's qcow2 is
# sparse, so the image only grows as the guest writes.
# Override: `just --set disk 200 start`.
disk := `echo $(( $(df -k / | awk 'NR==2 {print $4}') / 1024 / 1024 / 2 ))`

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
    {{nix_shell}} limactl start --name={{vm}} --cpus={{cpus}} --memory={{memory}} --disk={{disk}} --yes $(nix build --no-link --print-out-paths .#lima-template)
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

# Wipe the VM and start fresh (leading `-` tolerates a non-existent VM)
[group('lifecycle')]
recreate vm=name:
    -{{nix_shell}} limactl delete --force {{vm}}
    just start {{vm}}

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
