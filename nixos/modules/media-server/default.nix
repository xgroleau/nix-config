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
    users.deterministicIds = {
      jellyfin = {
        uid = 968;
        gid = 968;
      };
      bazarr = {
        uid = 967;
        gid = 967;
      };
      readarr = {
        uid = 966;
        gid = 966;
      };
      media.gid = 951;
    };

    virtualisation.oci-containers = {
      containers = {
        mediaserver-gluetun = {
          autoStart = true;
          image = "ghcr.io/qdm12/gluetun:v3.41.1@sha256:1a5bf4b4820a879cdf8d93d7ef0d2d963af56670c9ebff8981860b6804ebc8ab";
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
            "--cap-add=NET_RAW"
            "--device=/dev/net/tun"
          ];
          environment = {
            HTTPPROXY = "on";
            HTTPPROXY_PORT = "8118";
          };
          environmentFiles = [ cfg.gluetunEnvFile ];
        };

        mediaserver-deluge = {
          autoStart = true;
          dependsOn = [ "mediaserver-gluetun" ];
          #TODO:  Waiting on https://github.com/linuxserver/docker-deluge/issues/229
          # image = "linuxserver/deluge:2.2.0@sha256:6ae1d992859c1afaec200a1ec703a26afa97f82f3780ca4e5c224d1531bc1bf0";
          image = "linuxserver/deluge:2.2.0-r1-ls364";
          volumes = [
            "${cfg.dataDir}/deluge:/config"
            "${cfg.downloadDir}:/downloads"
          ];
          environment = {
            PUID = "0";
            PGID = "0";
            UMASK = "000";
          };
          extraOptions = [
            "--network=container:mediaserver-gluetun"
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

      flaresolverr = {
        enable = true;
        port = 8191;
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
        package = pkgs.unstable.jellyfin;
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

    users.users.jellyfin.extraGroups = [
      "render"
      "video"
    ];
    users.groups.media.members = with config.services; [
      bazarr.user
      radarr.user
      readarr.user
      sonarr.user
      jellyfin.user
    ];

    modules.authentik.blueprints.media-server = lib.mkIf config.modules.authentik.enable ''
      version: 1
      metadata:
        name: media-server
      entries:
        - id: jellyfin-app
          model: authentik_core.application
          identifiers:
            slug: jellyfin
          attrs:
            name: Jellyfin
            slug: jellyfin
            group: media
            meta_description: Jellyfin, a streaming platform
            meta_launch_url: https://jellyfin.xgroleau.com
            meta_icon: https://cdn.jsdelivr.net/gh/selfhst/icons/svg/jellyfin.svg
            open_in_new_tab: true
            policy_engine_mode: any

        - id: jellyfin-media-binding
          model: authentik_policies.policybinding
          identifiers:
            target: !KeyOf jellyfin-app
            order: 0
          attrs:
            enabled: true
            order: 0
            negate: false
            failure_result: false
            timeout: 30
            group: !Find [authentik_core.group, [name, media]]

        - id: jellyseerr-app
          model: authentik_core.application
          identifiers:
            slug: jellyseerr
          attrs:
            name: Jellyseerr
            slug: jellyseerr
            group: media
            meta_description: Allows you to make request to add stuff on jellyfin
            meta_launch_url: https://jellyseerr.xgroleau.com
            meta_icon: https://cdn.jsdelivr.net/gh/selfhst/icons/svg/jellyseerr.svg
            open_in_new_tab: true
            policy_engine_mode: any

        - id: jellyseerr-media-binding
          model: authentik_policies.policybinding
          identifiers:
            target: !KeyOf jellyseerr-app
            order: 0
          attrs:
            enabled: true
            order: 0
            negate: false
            failure_result: false
            timeout: 30
            group: !Find [authentik_core.group, [name, media]]
    '';
  };
}
