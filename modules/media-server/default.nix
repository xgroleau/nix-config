{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.media-server;
  group = "media";
  delugeUser = "delugevpn";
in
{
  options.modules.media-server = with lib.types; {
    enable = lib.mkEnableOption "A media server configuration";

    openFirewall = lib.mkEnableOption "Open the required ports in the firewall";

    dataDir = lib.mkOption {
      type = types.str;
      description = "Path where the data will be stored";
    };

    mediaDir = lib.mkOption {
      type = types.str;
      description = "Path where the media will be stored";
    };

    downloadDir = lib.mkOption {
      type = types.str;
      description = "Path where the download will be stored";
    };

    ovpnFile = lib.mkOption {
      type = types.str;
      description = "Path to ovpn config file, auth needs to be embedded in the file";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers = {
      containers = {
        delugevpn = {
          autoStart = true;
          image = "binhex/arch-delugevpn:2.1.1-4-05";
          ports = [
            "8112:8112"
            "8118:8118"
            "58846:58846"
            "58946:58946"
          ];
          volumes = [
            "${cfg.dataDir}/deluge:/config"
            "${cfg.downloadDir}:/data"
            "${cfg.ovpnFile}:/config/openvpn/vpn.ovpn"
          ];
          extraOptions = [
            "--cap-add=NET_ADMIN"
            "--privileged=true"
          ];
          environment = {
            VPN_ENABLED = "yes";
            VPN_PROV = "custom";
            VPN_CLIENT = "openvpn";
            STRICT_PORT_FORWARD = "yes";
            ENABLE_PRIVOXY = "yes";
            LAN_NETWORK = "10.0.0.0/8,172.16.0.0/12,192.168.0.0/16";
            NAME_SERVERS = "84.200.69.80,37.235.1.174,1.1.1.1,37.235.1.177,84.200.70.40,1.0.0.1,8.8.8.8";
            DELUGE_DAEMON_LOG_LEVEL = "info";
            DELUGE_WEB_LOG_LEVEL = "info";
            DELUGE_ENABLE_WEBUI_PASSWORD = "yes";
            VPN_INPUT_PORTS = "";
            VPN_OUTPUT_PORTS = "";
            DEBUG = "false";
            UMASK = "000";
            PUID = "0";
            PGID = "0";
          };
        };
      };
    };

    # Expose ports for container
    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [
        8112
        8118
        58846
        58946
      ];
      allowedUDPPorts = [
        8112
        8118
        58846
        58946
      ];
    };

    # Create a directory for the container to properly start
    systemd.tmpfiles.settings.delugevpn = {
      "${cfg.dataDir}/deluge" = {
        d = {
          inherit group;
          mode = "0775";
          user = "root";
        };
      };
      "${cfg.mediaDir}/movies" = {
        d = {
          inherit group;
          mode = "0775";
          user = "root";
        };
      };
      "${cfg.mediaDir}/shows" = {
        d = {
          inherit group;
          mode = "0775";
          user = "root";
        };
      };
      "${cfg.mediaDir}/books" = {
        d = {
          inherit group;
          mode = "0775";
          user = "root";
        };
      };
      "${cfg.downloadDir}" = {
        d = {
          inherit group;
          mode = "0775";
          user = "root";
        };
      };
    };

    services = {

      prowlarr = {
        enable = true;
        openFirewall = cfg.openFirewall;
      };

      bazarr = {
        inherit group;
        enable = true;
        listenPort = 6767;
        openFirewall = cfg.openFirewall;
      };

      radarr = {
        inherit group;
        enable = true;
        openFirewall = cfg.openFirewall;
        dataDir = cfg.dataDir + "/radarr";
      };

      readarr = {
        inherit group;
        enable = true;
        openFirewall = cfg.openFirewall;
        dataDir = cfg.dataDir + "/readarr";
      };

      sonarr = {
        inherit group;
        enable = true;
        openFirewall = cfg.openFirewall;
        dataDir = cfg.dataDir + "/sonarr";
      };

      jellyfin = {
        inherit group;
        enable = true;
        openFirewall = cfg.openFirewall;
        dataDir = cfg.dataDir + "/jellyfin";
      };

      jellyseerr = {
        enable = true;
        port = 5055;
        openFirewall = cfg.openFirewall;
      };
    };

    # And overwrite prowlarr's default systemd unit to run with the correct user/group
    systemd.services.prowlarr = {
      serviceConfig = {
        User = "prowlarr";
        Group = group;
      };
    };

    users.groups.media.members = with config.services; [
      bazarr.user
      radarr.user
      readarr.user
      sonarr.user
      jellyfin.user
    ];
  };
}
