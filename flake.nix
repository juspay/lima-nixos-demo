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

      # Lima template YAML, pinned to our locked nixos-lima input. Keep the
      # nixos-lima guest integration defaults, but replace broad host mounts
      # with a narrow scratch directory for explicit file transfer.
      #
      # Rosetta is enabled unconditionally: on macOS 13+ Apple Silicon hosts
      # this lets the aarch64 guest run x86_64 Linux binaries at near-native
      # speed via binfmt_misc. Intel Macs and Linux hosts ignore the field,
      # so it is safe to always emit. Requires the vz driver (the upstream
      # nixos-lima default).
      packages = forEach systems (system:
        let pkgs = nixpkgs.legacyPackages.${system}; in {
          lima-template = pkgs.runCommand "nixden-lima-template" {
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
              | .vmOpts.vz.rosetta.enabled = true
              | .vmOpts.vz.rosetta.binfmt = true
              | .message = strenv(NIXDEN_MESSAGE)
            ' ${nixos-lima}/.lima.yaml > $out
          '';
        });
    };
}
