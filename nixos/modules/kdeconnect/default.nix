{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.kdeconnect;
in
{

  options.modules.kdeconnect = {
    enable = lib.mkEnableOption "Enables the kde connect service ports";
  };

  config = lib.mkIf cfg.enable {

    networking.firewall = {
      allowedTCPPortRanges = [
        {
          from = 1714;
          to = 1764;
        }
      ];
      allowedUDPPortRanges = [
        {
          from = 1714;
          to = 1764;
        }
      ];
    };

  };
}
