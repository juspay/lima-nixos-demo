{ nixpkgs, nixos-lima, nixos-vscode-server, ... }:

let
  system = "aarch64-linux";
in
{
  nixosConfigurations.devbox = nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [
      nixos-lima.nixosModules.lima
      nixos-vscode-server.nixosModules.default
      ./nixos/configuration.nix
    ];
  };
}
