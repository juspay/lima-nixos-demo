nix_shell := if env('IN_NIX_SHELL', '') != '' { '' } else { 'nix develop -c' }
name := "devbox"
template_url := "https://github.com/juspay/devbox/releases/latest/download/devbox-lima.yaml"

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

# The latest release publishes a ready-to-use Lima template with image
# URLs and SHA-512 digests baked in.

# Create and start the NixOS VM from the latest release image
[group('lifecycle')]
start vm=name:
    {{nix_shell}} limactl start --name={{vm}} --cpus={{cpus}} --memory={{memory}} --disk={{disk}} --yes "{{template_url}}"

# `--workdir /tmp` keeps CWD off Lima's Users-<user> 9p mount so that
# switch-to-configuration can restart that mount unit cleanly.

# Apply our NixOS config inside the VM (idempotent)
[group('lifecycle')]
provision vm=name:
    {{nix_shell}} limactl shell --workdir /tmp {{vm}} -- sudo nixos-rebuild switch --flake $(pwd)#devbox

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

# --- Release ---

# Create a GitHub release and start image uploads
[group('release')]
release version:
    {{nix_shell}} gh release create "{{version}}" --repo juspay/devbox --target main --title "Release {{version}}" --notes "Devbox image release {{version}}"
    {{nix_shell}} gh workflow run release-images.yml --repo juspay/devbox --ref main -f tag="{{version}}"

# Recreate the mutable dev prerelease from the current branch
[group('release')]
release-development tag="dev":
    #!/usr/bin/env bash
    set -euo pipefail
    branch="$(git branch --show-current)"
    if [ -z "$branch" ]; then
      echo "release-development must be run from a branch, not detached HEAD" >&2
      exit 1
    fi
    {{nix_shell}} gh release delete "{{tag}}" --repo juspay/devbox --yes --cleanup-tag || true
    {{nix_shell}} gh release create "{{tag}}" \
      --repo juspay/devbox \
      --target "$branch" \
      --title "Development" \
      --notes "Mutable development image release from $branch" \
      --prerelease
    {{nix_shell}} gh workflow run release-images.yml --repo juspay/devbox --ref "$branch" -f tag="{{tag}}"
