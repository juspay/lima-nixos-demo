{ config, lib, pkgs, modulesPath, username, nixos-vscode-server, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  # Enable Lima guest integration (lima-init: user creation from cidata,
  # ssh key install, mount setup from user-data, lima-guestagent service).
  # This is the only thing `nixos-lima.nixosModules.lima` actually provides.
  services.lima.enable = true;

  # Lima creates the guest user imperatively via lima-init at first boot
  # (useradd with the macOS host's UID). Declaring the user here without a
  # UID lets NixOS's user module coexist: if the user already exists, the
  # activation is a no-op — it just makes HM's NixOS module happy (HM reads
  # `config.users.users.${name}.{name,home}`).
  users.users.${username} = {
    isNormalUser = true;
    home = "/home/${username}.guest";
    group = "users";
    extraGroups = [ "wheel" ];
    createHome = false;
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  services.openssh.enable = true;
  security.sudo.wheelNeedsPassword = false;

  # Run random prebuilt Linux binaries (VSCode server is handled separately
  # via nixos-vscode-server, but other tools benefit from nix-ld too).
  programs.nix-ld.enable = true;

  # Persist user systemd services (vscode-server, future `code tunnel`)
  # across logouts / reboots without requiring an active login session.
  systemd.tmpfiles.rules = [
    "f /var/lib/systemd/linger/${username} 0644 root root -"
  ];

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

  environment.systemPackages = with pkgs; [ vim ];

  # Apply home-manager as part of this system's activation so a single
  # `nixos-rebuild switch` provisions both system and user config.
  home-manager = {
    useGlobalPkgs = true;
    # Lima manages the guest user's home imperatively; avoid per-user
    # package linking into users.users.<user>.packages.
    useUserPackages = false;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = { inherit username; };
    sharedModules = [ nixos-vscode-server.homeModules.default ];
    users.${username} = import ../home/home.nix;
  };

  system.stateVersion = "25.11";
}
