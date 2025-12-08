{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.media-server;
  group = "media";
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

    gluetunEnvFile = lib.mkOption {
      type = types.str;
      description = "Path to env config file for gluetun";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers = {
      containers = {
        gluetun = {
          autoStart = true;
          image = "ghcr.io/qdm12/gluetun:v3.40.3@sha256:ef4a44819a60469682c7b5e69183e6401171891feaa60186652d292c59e41b30";
          ports = [
            "8112:8112"
            "8118:8118"
            "58846:58846"
            "58946:58946"
            "58946:58946/udp"
          ];
          volumes = [
            "${cfg.dataDir}/gluetun:/gluetun"
          ];
          extraOptions = [
            "--cap-add=NET_ADMIN"
            "--device=/dev/net/tun"
          ];
          environment = {
            TZ = config.time.timeZone;
            HTTPPROXY = "on";
            HTTPPROXY_PORT = "8118";
          };
          environmentFiles = [ cfg.gluetunEnvFile ];
        };

        deluge = {
          autoStart = true;
          dependsOn = [ "gluetun" ];
          image = "linuxserver/deluge:2.2.0@sha256:0eb19323676546fd560882036ecee982c387d016170906231864bc92d3cd38db";
          volumes = [
            "${cfg.dataDir}/deluge:/config"
            "${cfg.downloadDir}:/data"
          ];
          environment = {
            PUID = "0";
            PGID = "0";
            UMASK = "000";
            TZ = config.time.timeZone;
          };
          extraOptions = [
            "--network=container:gluetun"
          ];
        };
      };
    };

    # Expose ports for container
    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [
        8118
        58846
        58946
      ];
      allowedUDPPorts = [
        58946
      ];
    };

    # Create a directory for the container to properly start
    systemd.tmpfiles.settings.media-server = {
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
      "${cfg.dataDir}/gluetun" = {
        d = {
          inherit group;
          mode = "0770";
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
