{
  lib,
  inputs,
  hostConfig,
  ...
}:

{

  imports = [
    ./modules
    (
      if (hostConfig.useUnstable or false) then
        inputs.home-manager-unstable.nixosModules.home-manager
      else
        inputs.home-manager.nixosModules.home-manager
    )
    inputs.agenix.nixosModules.default
    inputs.disko.nixosModules.disko
    inputs.authentik-nix.nixosModules.default
    inputs.preservation.nixosModules.preservation
  ]
  ++ lib.optional (hostConfig.useUnstable or false) inputs.jovian-nixos.nixosModules.default;

}
