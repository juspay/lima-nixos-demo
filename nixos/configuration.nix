{ lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  # Enable Lima guest integration (lima-init: user creation from cidata,
  # ssh key install, mount setup from user-data, lima-guestagent service).
  # This is the only thing `nixos-lima.nixosModules.lima` actually provides.
  services.lima.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  services.openssh.enable = true;
  security.sudo.wheelNeedsPassword = false;

  # Run random prebuilt Linux binaries (VSCode server is handled separately
  # via nixos-vscode-server, but other tools benefit from nix-ld too).
  programs.nix-ld.enable = true;
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
  programs.starship.enable = true;

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

  boot.kernelPackages = pkgs.linuxPackages_latest;

  environment.systemPackages = with pkgs; [
    git
    home-manager
    just
    vim
  ];

  system.stateVersion = "25.11";
}
