name := "devbox"
exchange_dir := env('DEVBOX_EXCHANGE_DIR', env('HOME') + "/Shared/devbox-exchange")
artifacts_dir := env('DEVBOX_ARTIFACTS_DIR', env('HOME') + "/Library/Caches/" + name)

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

# Build a local qcow2 image inside a temporary NixOS builder VM
[group('lifecycle')]
build-image vm=name:
    #!/usr/bin/env bash
    set -euo pipefail
    repo="$(pwd)"
    linux_system="${DEVBOX_TARGET_SYSTEM:-}"
    lima_arch="${DEVBOX_LIMA_ARCH:-}"
    if [ -z "$linux_system" ]; then
      case "$(uname -m)" in
        arm64|aarch64) linux_system="aarch64-linux" ;;
        x86_64) linux_system="x86_64-linux" ;;
        *) echo "Unsupported host architecture: $(uname -m)" >&2; exit 1 ;;
      esac
    fi
    if [ -z "$lima_arch" ]; then
      case "$linux_system" in
        aarch64-linux) lima_arch="aarch64" ;;
        x86_64-linux) lima_arch="x86_64" ;;
        *) echo "Unsupported target system: $linux_system" >&2; exit 1 ;;
      esac
    fi
    artifacts_dir="{{artifacts_dir}}"
    image_path="$artifacts_dir/{{vm}}.qcow2"
    template_path="$artifacts_dir/{{vm}}.yaml"
    builder_template="${DEVBOX_BUILDER_TEMPLATE:-}"
    if [ -z "$builder_template" ]; then
      builder_template="$repo/lima/builder.yaml.in"
    fi
    mkdir -p "$artifacts_dir"
    limactl delete --force "{{vm}}-builder" >/dev/null 2>&1 || true
    cleanup() {
      limactl stop "{{vm}}-builder" >/dev/null 2>&1 || true
      limactl delete --force "{{vm}}-builder" >/dev/null 2>&1 || true
    }
    trap cleanup EXIT
    mount_args=()
    if [[ "$builder_template" != http* ]] && grep -q '__REPO_LOCATION__' "$builder_template"; then
      mounted_builder_template="$artifacts_dir/{{vm}}-builder.yaml"
      sed "s|__REPO_LOCATION__|$repo|g" "$builder_template" > "$mounted_builder_template"
      builder_template="$mounted_builder_template"
    elif limactl start --help | grep -q -- '--mount-only'; then
      mount_args=(--mount-only "$repo")
    else
      mount_args=(--mount "$repo")
    fi
    limactl start --arch="$lima_arch" --name="{{vm}}-builder" --cpus={{cpus}} --memory={{memory}} --disk={{disk}} "${mount_args[@]}" --yes "$builder_template"
    just provision-system "$linux_system" "{{vm}}-builder"
    image_store_path="$(
      limactl shell --workdir "$repo" "{{vm}}-builder" -- \
        bash -lc "nix build --no-link --print-out-paths '$repo'#packages.$linux_system.devbox-image"
    )"
    rm -f "$image_path"
    limactl copy --backend=scp "{{vm}}-builder:${image_store_path}" "$image_path"
    sed "s|__IMAGE_LOCATION__|file://$image_path|g" "$repo/lima/local-image.yaml.in" > "$template_path"

# Apply the NixOS system config inside a running builder VM.
[group('lifecycle')]
provision-system linux_system vm=name:
    #!/usr/bin/env bash
    set -euo pipefail
    repo="$(pwd)"
    limactl shell --workdir /tmp "{{vm}}" -- sudo nixos-rebuild switch --flake "$repo#devbox-{{linux_system}}"

# Create and start the working VM from the locally built qcow2
[group('lifecycle')]
start vm=name:
    #!/usr/bin/env bash
    set -euo pipefail
    repo="$(pwd)"
    artifacts_dir="{{artifacts_dir}}"
    template_path="$artifacts_dir/{{vm}}.yaml"
    lima_arch="${DEVBOX_LIMA_ARCH:-}"
    arch_args=()
    if [ -n "$lima_arch" ]; then
      arch_args=(--arch="$lima_arch")
    fi
    mkdir -p "{{exchange_dir}}" "$artifacts_dir"
    if [ ! -f "$template_path" ]; then
      just build-image "{{vm}}"
    fi
    if [ -d "$HOME/.lima/{{vm}}" ]; then
      limactl start "{{vm}}"
    else
      mount_args=()
      if limactl start --help | grep -q -- '--mount-only'; then
        mount_args=(--mount-only "$repo" --mount-only "{{exchange_dir}}:w")
        for mount_spec in ${DEVBOX_EXTRA_MOUNTS:-}; do
          mount_args+=(--mount-only "$mount_spec")
        done
      else
        mount_args=(--mount "$repo" --mount "{{exchange_dir}}:w")
        for mount_spec in ${DEVBOX_EXTRA_MOUNTS:-}; do
          mount_args+=(--mount "$mount_spec")
        done
      fi
      limactl start "${arch_args[@]}" --name="{{vm}}" --cpus={{cpus}} --memory={{memory}} --disk={{disk}} "${mount_args[@]}" --yes "$template_path"
    fi

# Stop the VM
[group('lifecycle')]
stop vm=name:
    limactl stop "{{vm}}"

# Remove the VM (destructive)
[group('lifecycle')]
delete vm=name:
    limactl delete "{{vm}}"

# Wipe the VM and start fresh from the current local image
[group('lifecycle')]
recreate vm=name:
    -limactl delete --force "{{vm}}"
    just start "{{vm}}"

# List all Lima VMs
[group('lifecycle')]
list:
    limactl list

# --- Access ---

# Open a shell in the VM
[group('access')]
shell vm=name:
    limactl shell "{{vm}}"

# Print Lima's generated SSH config for the VM
[group('access')]
ssh-config vm=name:
    limactl show-ssh --format=config "{{vm}}"

# SSH into the VM using Lima's generated config (no global config mutation)
[group('access')]
ssh vm=name *args='':
    ssh -F ~/.lima/{{vm}}/ssh.config lima-{{vm}} {{args}}
