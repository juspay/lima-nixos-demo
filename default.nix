{ nixpkgs, nixos-lima, home-manager, nixos-vscode-server, ... }:

let
  lib = nixpkgs.lib;
  linuxSystems = [ "aarch64-linux" "x86_64-linux" ];
  configName = system: "devbox-${system}";
  username =
    let u = builtins.getEnv "USER";
    in
    if u == "" then
      throw "USER env var not set — preserve USER and pass --impure when evaluating Home Manager."
    else
      u;
  homeDirectory =
    let h = builtins.getEnv "HOME";
    in
    if h == "" then
      throw "HOME env var not set — preserve HOME and pass --impure when evaluating Home Manager."
    else
      h;

  mkNixosConfiguration = system:
    nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit home-manager nixos-vscode-server; };
      modules = [
        nixos-lima.nixosModules.lima
        ./nixos/configuration.nix
      ];
    };

  nixosConfigurations = builtins.listToAttrs (map
    (system: {
      name = configName system;
      value = mkNixosConfiguration system;
    })
    linuxSystems);

  homeConfigurations = builtins.listToAttrs (map
    (system: {
      name = configName system;
      value = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.${system};
        extraSpecialArgs = { inherit username homeDirectory nixos-vscode-server; };
        modules = [
          nixos-vscode-server.homeModules.default
          ./home/home.nix
        ];
      };
    })
    linuxSystems);

  packages = builtins.listToAttrs (map
    (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        config = nixosConfigurations.${configName system}.config;
        imageDrv =
          if builtins.hasAttr "qemu-efi" config.system.build.images then
            config.system.build.images."qemu-efi"
          else
            config.system.build.images.qemu;
      in
      {
        name = system;
        value = {
          devbox-image = pkgs.runCommand "devbox-${system}.qcow2" { } ''
            src="$(find ${imageDrv} -type f -name '*.qcow2' | head -n 1)"
            if [ -z "$src" ]; then
              echo "No qcow2 image found under ${imageDrv}" >&2
              exit 1
            fi
            cp "$src" "$out"
          '';
        };
      })
    linuxSystems);
in
{
  inherit homeConfigurations nixosConfigurations packages;
}
