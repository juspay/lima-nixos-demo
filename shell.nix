{ pkgs }:

pkgs.mkShell {
  packages = with pkgs; [
    lima
    just
  ];
}
