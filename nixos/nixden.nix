{ pkgs, ... }:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  services.openssh.enable = true;
  security.sudo.wheelNeedsPassword = false;

  programs.starship.enable = true;
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Run random prebuilt Linux binaries (VSCode server is handled separately
  # via nixos-vscode-server, but other tools benefit from nix-ld too).
  programs.nix-ld.enable = true;
  services.vscode-server.enable = true;

  # Run x86_64 Linux binaries on Apple Silicon via Rosetta. Lima's vz driver
  # exposes the Rosetta runtime as a virtiofs share with tag `vz-rosetta`
  # (NixOS defaults to UTM's `rosetta`). On non-Apple-Silicon hosts the share
  # is absent; the systemd mount unit fails harmlessly and binfmt_misc stays
  # unregistered.
  virtualisation.rosetta = {
    enable = true;
    mountTag = "vz-rosetta";
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;

  environment.systemPackages = with pkgs; [
    btop
    gh
    just
    vim
  ];

  system.stateVersion = "25.11";
}
