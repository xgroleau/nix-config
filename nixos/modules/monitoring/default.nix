{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./server.nix
    ./target.nix
  ];
}
