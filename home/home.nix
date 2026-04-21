{ pkgs, username, ... }:

{
  home.username = username;
  # Lima convention: the guest user's home lives at /home/<user>.guest.
  # (Lima also mounts the host's /Users/<user> into the guest at the same path.)
  home.homeDirectory = "/home/${username}.guest";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  # Required for HM to inject shell integration (starship init, direnv hook,
  # etc.) into the user's bash init files. Without this, `programs.*.enable`
  # modules that rely on shell hooks are silently no-ops.
  programs.bash.enable = true;

  programs.starship.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.btop.enable = true;

  # `gh` CLI — useful for agentic GitHub work (issues, PRs, reviews) from
  # the VM without leaving the shell.
  programs.gh.enable = true;

  services.vscode-server.enable = true;

  home.packages = [ pkgs.just ];
}
