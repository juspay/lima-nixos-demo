{ pkgs, username, ... }:

{
  home.username = username;
  home.homeDirectory = "/home/${username}.guest";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  programs.starship.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.btop.enable = true;
  programs.gh.enable = true;

  services.vscode-server.enable = true;
}
