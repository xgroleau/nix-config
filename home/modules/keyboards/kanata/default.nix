{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.keyboards.kanata;
in
{

  options.modules.keyboards.kanata = {
    enable = lib.mkEnableOption "Enable kanata for keyboard remaps";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      kanata
    ];
  };

}
