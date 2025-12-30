{
  config,
  lib,
  pkgs,
  inputs,
  hostConfig,
  ...
}:

let
  cfg = config.nixos;

in
{

  imports = [
    ./modules
    inputs.home-manager.nixosModules.home-manager
    inputs.agenix.nixosModules.default
    inputs.disko.nixosModules.disko
    inputs.authentik-nix.nixosModules.default
  ]
  ++ lib.optional (hostConfig.useUnstable or false) inputs.jovian-nixos.nixosModules.default;

}
