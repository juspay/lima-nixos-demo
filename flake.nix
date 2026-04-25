{
  description = "nixden: NixOS based nixden on macOS (custom NixOS on Lima)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-lima = {
      url = "github:nixos-lima/nixos-lima/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-vscode-server = {
      url = "github:nix-community/nixos-vscode-server";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ nixpkgs, nixos-lima, ... }:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
      darwinSystems = [ "aarch64-darwin" "x86_64-darwin" ];
      forEach = nixpkgs.lib.genAttrs;
      base = import ./default.nix inputs;
      limaMessage = ''
        nixden is ready.

        Open a shell:
          limactl shell --workdir=. {{.Name}}

        This template intentionally does not mount your macOS home directory.
        Clone repositories inside the VM, for example under ~/code.

        To transfer files intentionally, use /tmp/lima-nixden on the host and
        inside the VM.
      '';

      # Lima template YAML, pinned to our locked nixos-lima input. Keep the
      # nixos-lima guest integration defaults, but replace broad host mounts
      # with a narrow scratch directory for explicit file transfer.
      #
      # Rosetta is enabled unconditionally: on macOS 13+ Apple Silicon hosts
      # this lets the aarch64 guest run x86_64 Linux binaries at near-native
      # speed via binfmt_misc. Intel Macs and Linux hosts ignore the field,
      # so it is safe to always emit. Requires the vz driver (the upstream
      # nixos-lima default).
      mkLimaTemplate = pkgs: pkgs.runCommand "nixden-lima-template" {
        nativeBuildInputs = [ pkgs.yq-go ];
        NIXDEN_MESSAGE = limaMessage;
      } ''
        yq -P '
          .mounts = [
            {
              "location": "/tmp/lima-nixden",
              "mountPoint": "/tmp/lima-nixden",
              "writable": true,
              "9p": {
                "cache": "mmap"
              }
            }
          ]
          | .rosetta.enabled = true
          | .rosetta.binfmt = true
          | .message = strenv(NIXDEN_MESSAGE)
        ' ${nixos-lima}/.lima.yaml > $out
      '';

      # Asserts the Rosetta toggle and scratch-mount invariants survive the yq
      # pipeline so a future refactor can't silently drop them. Cheap to run:
      # pure yq queries on a tiny YAML file. Exercised by `nix flake check`.
      mkLimaTemplateTest = pkgs: template:
        pkgs.runCommand "lima-template-rosetta-test"
          { nativeBuildInputs = [ pkgs.yq-go ]; }
          ''
            set -euo pipefail
            template=${template}

            enabled=$(yq -r '.rosetta.enabled' "$template")
            binfmt=$(yq -r '.rosetta.binfmt' "$template")
            mount_point=$(yq -r '.mounts[0].mountPoint' "$template")
            mount_count=$(yq -r '.mounts | length' "$template")

            if [ "$enabled" != "true" ]; then
              echo "expected .rosetta.enabled = true, got: $enabled" >&2
              exit 1
            fi
            if [ "$binfmt" != "true" ]; then
              echo "expected .rosetta.binfmt = true, got: $binfmt" >&2
              exit 1
            fi
            if [ "$mount_point" != "/tmp/lima-nixden" ]; then
              echo "expected scratch mount /tmp/lima-nixden, got: $mount_point" >&2
              exit 1
            fi
            if [ "$mount_count" != "1" ]; then
              echo "expected exactly one host mount, got: $mount_count" >&2
              exit 1
            fi

            touch $out
          '';
    in
    base // {
      devShells = forEach systems (system:
        let pkgs = nixpkgs.legacyPackages.${system}; in {
          default = import ./shell.nix { inherit pkgs; };
          ci = pkgs.mkShell {
            packages = with pkgs; [
              coreutils
              gh
              jq
              qemu
              yq-go
            ];
          };
        });

      packages = forEach systems (system:
        let pkgs = nixpkgs.legacyPackages.${system}; in {
          lima-template = mkLimaTemplate pkgs;
        });

      checks = forEach systems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          template = mkLimaTemplate pkgs;
        in {
          lima-template-rosetta = mkLimaTemplateTest pkgs template;
        });
    };
}
