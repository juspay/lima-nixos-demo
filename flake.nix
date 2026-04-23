{
  description = "devbox: NixOS based devbox on macOS (custom NixOS on Lima)";

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
      darwinSystems = [ "aarch64-darwin" "x86_64-darwin" ];
      forEach = nixpkgs.lib.genAttrs;
      base = import ./default.nix inputs;
    in
    base // {
      devShells = forEach darwinSystems (system: {
        default = import ./shell.nix { pkgs = nixpkgs.legacyPackages.${system}; };
      });

      # Lima template YAML, pinned to our locked nixos-lima input. Passes
      # through unmodified today; to apply local overrides (e.g. writable
      # mounts), swap the `cp` for a `yq` transform, for example:
      #   nativeBuildInputs = [ pkgs.yq-go ];
      #   yq '.mounts |= map(.writable = true)' ${nixos-lima}/.lima.yaml > $out
      packages = forEach darwinSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system}; in {
          lima-template = pkgs.runCommand "nixos-lima-template" { } ''
            cp ${nixos-lima}/.lima.yaml $out
          '';
        });
    };
}
