{ pkgs }:

pkgs.mkShell {
  packages = with pkgs; [
    git-cliff
    gh
    lima
    just
  ];
}
