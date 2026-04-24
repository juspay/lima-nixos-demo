{ pkgs }:

pkgs.mkShell {
  packages = with pkgs; [
    gh
    jq
    lima
    just
    yq-go
  ];
}
