{
  config,
  lib,
  ...
}:

let
  cfg = config.modules.nixpkgs;
in
{

  options.modules.nixpkgs = {
    enable = lib.mkEnableOption "Enable common nix configurations";
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.config.allowUnfree = true;
    xdg.configFile.nixpkgs.source = ./config;
  };
}
