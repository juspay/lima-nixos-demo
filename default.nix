{ nixpkgs, nixos-lima, home-manager, nixos-vscode-server, ... }:

let
  system = "aarch64-linux";
  # Read from $USER at flake eval time (requires `--impure`). The guest user
  # Lima creates matches the macOS host user, so passing $USER through from
  # the justfile yields the right name in the guest. Must be preserved across
  # the `sudo` boundary that nixos-rebuild crosses — see justfile.
  username =
    let u = builtins.getEnv "USER";
    in if u == "" then throw "USER env var not set — pass --impure and preserve USER across sudo." else u;
in
{
  nixosConfigurations.devbox = nixpkgs.lib.nixosSystem {
    inherit system;
    specialArgs = { inherit username nixos-vscode-server; };
    modules = [
      nixos-lima.nixosModules.lima
      home-manager.nixosModules.home-manager
      ./nixos/configuration.nix
    ];
  };
}
