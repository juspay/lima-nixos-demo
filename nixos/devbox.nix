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

  boot.kernelPackages = pkgs.linuxPackages_latest;

  environment.systemPackages = with pkgs; [
    btop
    gh
    just
    vim
  ];

  system.stateVersion = "25.11";
}
