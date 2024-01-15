{ config, lib, pkgs, ... }:

with lib;
with lib.my.option;
let
  cfg = config.modules.services.media-server;
  group = "media";
in {
  options.modules.services.media-server = {
    enable = mkEnableOption "A media server configuration";
    downloadPath = mkReq types.str "Path where the download will be done";

    ovpnFile = mkOption {
      description = "Path to ovpn config file";
      type = types.str;
    };

    ovpnUsernameFile = mkOption {
      description =
        "Path to file containing username to authenticate with VPN.";
      type = types.str;
    };

    ovpnPasswordFile = mkOption {
      description =
        "Path to file containing password to authenticate with VPN.";
      type = types.str;
    };

    ovpnAuthFile = mkOption {
      description =
        "Path to file containing password to authenticate with VPN.";
      type = types.str;
    };

  };

  config = mkIf cfg.enable {
    services.deluge = {
      inherit group;
      enable = true;
      extraPackages = [ pkgs.unrar ];
      web = {
        enable = true;
        openFirewall = true;
      };
    };

    services.jackett = {
      inherit group;
      enable = true;
      openFirewall = true;
    };

    services.lidarr = {
      inherit group;
      enable = true;
      openFirewall = true;
    };

    services.plex = {
      inherit group;
      enable = true;
      openFirewall = true;
    };

    services.sonarr = {
      inherit group;
      enable = true;
      openFirewall = true;
    };

    services.radarr = {
      inherit group;
      enable = true;
      openFirewall = true;
    };

    modules.networking.forced-vpn = {
      enable = true;
      servers."${group}" = {
        ovpnFile = cfg.ovpnFile;
        ovpnUsernameFile = cfg.ovpnUsernameFile;
        ovpnPasswordFile = cfg.ovpnPasswordFile;
        mark = "0x6";
        protocol = "udp";
        routeTableId = 42;
        users = [ config.services.jackett.user config.services.deluge.user ];
      };
    };

    users.groups.media.members = (with config.services; [
      deluge.user
      sonarr.user
      radarr.user
      plex.user
      lidarr.user
    ]);
  };
}
