{ lib, ... }:

{
  image.modules.qemu-efi = lib.mkForce (
    { config, lib, modulesPath, pkgs, ... }:
    let
      cfg = config.image;
    in
    {
      imports = [
        (modulesPath + "/virtualisation/disk-image.nix")
      ];

      system.build.image = lib.mkForce (import (modulesPath + "/../lib/make-disk-image.nix") {
        inherit lib config pkgs;
        inherit (config.virtualisation) diskSize;
        inherit (cfg) baseName format;
        memSize = 4096;
        partitionTableType = if cfg.efiSupport then "efi" else "legacy";
      });
    }
  );
}
