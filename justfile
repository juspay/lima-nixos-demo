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

# The latest release publishes a ready-to-use Lima template with image
# URLs and SHA-512 digests baked in.

# Create and start the NixOS VM from a release image
[group('lifecycle')]
start release="latest":
    #!/usr/bin/env bash
    set -euo pipefail
    release="{{release}}"
    if [ "$release" = "latest" ]; then
      template_url="https://github.com/juspay/devbox/releases/latest/download/devbox-lima.yaml"
    else
      template_url="https://github.com/juspay/devbox/releases/download/$release/devbox-lima.yaml"
    fi
    {{nix_shell}} limactl start --name={{name}} --cpus={{cpus}} --memory={{memory}} --disk={{disk}} --yes "$template_url"

# Delete Lima's downloaded devbox image cache for a release
[group('lifecycle')]
delete-downloaded-images release="dev":
    #!/usr/bin/env bash
    set -euo pipefail
    release="{{release}}"
    if [ "$(uname -s)" = "Darwin" ]; then
      cache_root="$HOME/Library/Caches/lima/download/by-url-sha256"
    else
      cache_root="${XDG_CACHE_HOME:-$HOME/.cache}/lima/download/by-url-sha256"
    fi

    [ -d "$cache_root" ] || exit 0
    for arch in aarch64 x86_64; do
      url="https://github.com/juspay/devbox/releases/download/$release/devbox-$release-$arch.qcow2"
      while IFS= read -r entry; do
        if [ -f "$entry/url" ] && grep -Fxq "$url" "$entry/url"; then
          rm -rf "$entry"
        fi
      done < <(find "$cache_root" -mindepth 1 -maxdepth 1 -type d)
    done

# Stop the VM
[group('lifecycle')]
stop:
    {{nix_shell}} limactl stop {{name}}

# Remove the VM (destructive)
[group('lifecycle')]
delete:
    {{nix_shell}} limactl delete {{name}}

# Wipe the VM and start fresh (leading `-` tolerates a non-existent VM)
[group('lifecycle')]
recreate release="latest":
    -{{nix_shell}} limactl delete --force {{name}}
    just delete-downloaded-images {{release}}
    just start {{release}}

# List all Lima VMs
[group('lifecycle')]
list:
    {{nix_shell}} limactl list

# --- Access ---

# Open a shell in the VM
[group('access')]
shell:
    {{nix_shell}} limactl shell {{name}}

# Print Lima's generated SSH config for the VM
[group('access')]
ssh-config:
    {{nix_shell}} limactl show-ssh --format=config {{name}}

# SSH into the VM using Lima's generated config (no global config mutation)
[group('access')]
ssh *args='':
    ssh -F ~/.lima/{{name}}/ssh.config lima-{{name}} {{args}}

# --- Release ---

# Print release notes generated from Conventional Commits since the latest tag
[group('release')]
release-notes version:
    @{{nix_shell}} git cliff --unreleased --tag "{{version}}" --strip header

# Create a GitHub release and start image uploads
[group('release')]
release version:
    #!/usr/bin/env bash
    set -euo pipefail
    notes_file="$(mktemp)"
    trap 'rm -f "$notes_file"' EXIT
    {{nix_shell}} git cliff --unreleased --tag "{{version}}" --strip header > "$notes_file"
    {{nix_shell}} gh release create "{{version}}" --repo juspay/devbox --target main --title "Release {{version}}" --notes-file "$notes_file"
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
