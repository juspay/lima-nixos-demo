{ lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./devbox.nix
  ];

  # Enable Lima guest integration (lima-init: user creation from cidata,
  # ssh key install, mount setup from user-data, lima-guestagent service).
  # This is the only thing `nixos-lima.nixosModules.lima` actually provides.
  services.lima.enable = true;

  # Boot/filesystem settings must match the stock nixos-lima qcow2 image.
  boot.loader.grub = {
    device = "nodev";
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  fileSystems."/boot" = {
    device = lib.mkForce "/dev/vda1";
    fsType = "vfat";
  };
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    autoResize = true;
    fsType = "ext4";
    options = [ "noatime" "nodiratime" "discard" ];
  };
}
