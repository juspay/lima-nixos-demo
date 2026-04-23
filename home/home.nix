{ username, homeDirectory, ... }:

{
  home.username = username;
  home.homeDirectory = homeDirectory;
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  programs.btop.enable = true;

  # `gh` CLI — useful for agentic GitHub work (issues, PRs, reviews) from
  # the VM without leaving the shell.
  programs.gh.enable = true;

  services.vscode-server.enable = true;
}
