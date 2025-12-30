{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.tailscale;
in
{

  options.modules.tailscale = {
    enable = lib.mkEnableOption "Enables tailscale service and open firewall for it";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ tailscale ];

    services.tailscale = {
      enable = true;
      openFirewall = true;
    };
  };
}
