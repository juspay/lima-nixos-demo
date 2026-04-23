{ nixpkgs, nixos-lima, nixos-vscode-server, ... }:

let
  mkDevbox = system:
    nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        nixos-lima.nixosModules.lima
        nixos-vscode-server.nixosModules.default
        ./nixos/configuration.nix
        ./nixos/release-images.nix
      ];
    };

  devboxAarch64 = mkDevbox "aarch64-linux";
  devboxX86_64 = mkDevbox "x86_64-linux";
in
{
  nixosConfigurations = {
    devbox = devboxAarch64;
    devbox-aarch64 = devboxAarch64;
    devbox-x86_64 = devboxX86_64;
  };
}
