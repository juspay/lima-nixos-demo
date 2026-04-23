{ pkgs }:

pkgs.mkShell {
  packages = with pkgs; [
    gh
    lima
    just
  ];
}
