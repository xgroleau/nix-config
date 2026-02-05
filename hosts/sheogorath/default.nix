{
  config,
  lib,
  pkgs,
  ...
}:

let
  domain = "xgroleau.com";
  mkLocalHost = port: "localhost:${toString port}";
  backupFolders = [
    "/vault"
    "/documents"
    "/data/backups"
    "/var/lib/jellyseerr"
  ];
in
{
  imports = [
    ../base-config.nix
    ../server-config.nix
    ./disko.nix
    ./hardware-configuration.nix
  ];

  config = {
    # Custom modules
    modules = {
      home = {
        enable = true;
        username = "xgroleau";
        profile = "minimal";
      };

      ssh.enable = true;
      secrets.enable = true;

      monitoring = {
        # Jyggalag monitors this server
        target = {
          enable = true;
          lokiAddress = "http://jyggalag:13100/loki/api/v1/push";
          prometheusPort = 13150;
          promtailPort = 13030;
        };
      };

      attic = {
        enable = true;
        port = 15000;
        dataDir = "/data/attic";
        environmentFile = config.age.secrets.atticEnv.path;
      };

      authentik = {
        enable = true;
        port = 9000;
        metricsPort = 9300;
        dataDir = "/data/authentik";
        backupDir = "/data/backups/authentik";
        mediaDir = "/vault/authentik/media";
        envFile = config.age.secrets.authentikEnv.path;
        ldap = {
          enable = true;
          ldapPort = 9389;
          ldapsPort = 9636;
          metricsPort = 9301;
        };
      };

      caddy = {
        enable = true;
        openFirewall = true;
        dataDir = "/data/caddy";
        email = "xavgroleau@gmail.com";
        reverseProxies = {
          "authentik.${domain}" = mkLocalHost config.modules.authentik.port;
          "firefly.${domain}" = mkLocalHost config.modules.firefly-iii.port;
          "immich.${domain}" = mkLocalHost config.modules.immich.port;
          "jellyfin.${domain}" = mkLocalHost (config.services.jellyfin.port or 8096);
          "jellyseerr.${domain}" = mkLocalHost (config.services.jellyseerr.port or 5055);
          "mealie.${domain}" = mkLocalHost config.modules.mealie.port;
          "miniflux.${domain}" = mkLocalHost config.modules.miniflux.port;
          "ntfy.${domain}" = mkLocalHost config.modules.ntfy.port;
          "opencloud.${domain}" = mkLocalHost config.modules.opencloud.port;
          "collabora.opencloud.${domain}" = mkLocalHost config.modules.opencloud.collabora.collaboraPort;
          "companion.opencloud.${domain}" = mkLocalHost config.modules.opencloud.collabora.companionPort;
          "paperless.${domain}" = mkLocalHost config.modules.paperlessNgx.port;
          "vaultwarden.${domain}" = mkLocalHost config.modules.vaultwarden.port;

          "overseerr.${domain}" = "unraid:5055"; # Temporary
          "overseerr.sheogorath.duckdns.org" = "unraid:5055"; # Temporary
          "foundry.${domain}" = "unraid:30000"; # Temporary
          "ddbi.${domain}" = "unraid:30001"; # Temporary
        };
      };

      firefly-iii = {
        enable = true;
        port = 12300;
        exporterPort = 12301;
        dataDir = "/vault/firefly-iii";
        appUrl = "https://firefly.${domain}";
        appKeyFile = config.age.secrets.fireflyAppKey.path;
        importerTokenFile = config.age.secrets.fireflyImporterToken.path;
        mail = {
          enable = true;
          host = "mail.gmx.com";
          from = "sheogorath@gmx.com";
          to = "xavgroleau@gmail.com";
          username = "xavgroleau@gmx.com";
          passwordFile = config.age.secrets.gmxPass.path;
        };
      };

      immich = {
        enable = true;
        port = 10300;
        configDir = "/vault/immich";
        dataDir = "/documents/immich";
        backupDir = "/data/backups/immich";
        databaseDir = "/data/immich/database";
        envFile = config.age.secrets.immichEnv.path;
      };

      media-server = {
        enable = true;
        dataDir = "/data/media-server";
        downloadDir = "/media/deluge-downloads";
        mediaDir = "/media/media";
        gluetunEnvFile = config.age.secrets.gluetunEnv.path;
      };

      opencloud = {
        enable = true;
        port = 11200;
        configDir = "/vault/opencloud";
        dataDir = "/documents/opencloud";
        environmentFiles = [ config.age.secrets.opencloudEnv.path ];
        domain = "opencloud.${domain}";
        collabora = {
          enable = true;
          collaboraPort = 11210;
          companionPort = 11220;
          collaboraDomain = "collabora.opencloud.xgroleau.com";
          companionDomain = "companion.opencloud.xgroleau.com";
        };
      };

      mealie = {
        enable = true;
        port = 10400;
        credentialsFile = config.age.secrets.mealieEnv.path;
        dataDir = "/vault/mealie";
      };

      miniflux = {
        enable = true;
        port = 10500;
        url = "https://miniflux.${domain}";
        envFile = config.age.secrets.minifluxEnv.path;
        dataDir = "/data/miniflux";
        backupDir = "/data/backups/miniflux";
      };

      msmtp = {
        enable = true;
        host = "mail.gmx.com";
        from = "sheogorath@gmx.com";
        to = "xavgroleau@gmail.com";
        username = "xavgroleau@gmx.com";
        passwordFile = config.age.secrets.gmxPass.path;
      };

      ntfy = {
        enable = true;
        url = "https://ntfy.${domain}";
        envFile = config.age.secrets.ntfyEnv.path;
        dataDir = "/data/ntfy";
        port = 10600;
      };

      # minecraft = {
      #   enable = true;
      #   port = 25665;
      #   openFirewall = true;

      #   name = "Yofo";
      #   type = "FORGE";
      #   version = "1.20.2";
      #   dataDir = "/data/minecraft/yofo";
      #   packwizPackUrl = "https://raw.githubusercontent.com/xgroleau/yofo-modpack/refs/tags/v1.0.5/pack.toml";
      # };

      arkSurvivalAscended = {
        enable = true;
        port = 7777;
        openFirewall = true;
        dataDir = "/data/arkSurvivalAscended";
      };

      # palworld = {
      #   enable = true;
      #   restart = true;
      #   port = 8211;
      #   openFirewall = true;
      #   dataDir = "/data/palworld";
      # };

      paperlessNgx = {
        enable = true;
        port = 10700;
        url = "https://paperless.${domain}";
        backupDir = "/data/backups/paperless";
        mediaDir = "/documents/paperless";
        dataDir = "/data/paperless";
        consumptionDir = "/documents/paperless/consumption";
        envFile = config.age.secrets.paperlessNgxEnv.path;
      };

      stalwart = {
        enable = true;
        dataDir = "/vault/stalwart";
        options.admin_password = config.age.secrets.stalwartEnv.path;
      };

      valheim = {
        enable = false;
        restart = true;
        port = 2456;
        name = "Yofo";
        password = "noobreport";
        openFirewall = true;
        dataDir = "/data/valheim";
      };

      vaultwarden = {
        enable = true;
        port = 10800;
        backupDir = "/data/backups/vaultwarden";
        domain = "vaultwarden.${domain}";
        envFile = config.age.secrets.vaultwardenEnv.path;
      };
    };

    services = {

      borgbackup.jobs."unraid" = {
        paths = backupFolders;
        exclude = [ ];
        repo = "ssh://borg@unraid:2222/backup/sheogorath";
        encryption = {
          mode = "none";
        };
        environment.BORG_RSH = "ssh -i /etc/ssh/ssh_host_ed25519_key";
        compression = "auto,lzma";
        startAt = "*-*-* 04:00:00";
        failOnWarnings = false;
        postHook = ''
          if [ $exitStatus -ne 0 ]; then
             echo -e "From: sheogorath@gmx.com\nTo: xavgroleau@gmail.com\nSubject: Borg unraid\n\nFailed to backup borg job unraid with exitcode $exitStatus\n" | ${pkgs.msmtp}/bin/msmtp -a default xavgroleau@gmail.com
          fi
        '';
      };

      cloudflare-dyndns = {
        enable = true;
        deleteMissing = false;
        domains = [ domain ];
        apiTokenFile = config.age.secrets.cloudflareXgroleau.path;
      };

      duplicati = {
        enable = true;
        port = 14000;
        interface = "0.0.0.0";
        user = "root";
      };

      fail2ban.enable = true;
    };

    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };

    networking = {
      useDHCP = true;
      hostId = "819a6cd7";
      hostName = "sheogorath";
    };

    # nfs mounts
    fileSystems."/mnt/nfs/shows" = {
      device = "unraid:/mnt/user/shows";
      fsType = "nfs";
      options = [
        "x-systemd.automount"
        "noauto"
      ];
    };

    fileSystems."/mnt/nfs/movies" = {
      device = "unraid:/mnt/user/movies";
      fsType = "nfs";
      options = [
        "x-systemd.automount"
        "noauto"
      ];
    };

    # Container backend
    virtualisation = {
      oci-containers.backend = "podman";
      podman = {
        enable = true;
        autoPrune = {
          enable = true;
          dates = "weekly";
          flags = [
            "--all"
            "--volumes"
          ];
        };
      };
    };

    system.stateVersion = "25.05";
  };
}
