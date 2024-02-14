{ config, lib, pkgs, inputs, ... }:

let cfg = config.modules.authentik;
in {

  imports = [ ];

  options.modules.authentik = with lib.types; {
    enable = lib.mkEnableOption ''
      Enables the authentik module, uses a nixos container under the hood so the postges db is a seperated service.
       Also uses ephemeral container, so you need to pass the media directory'';

    ldap = lib.mkOption {
      type = types.submodule {
        options = {
          enable = lib.mkEnableOption
            "Enables the authentik ldap outpost. The envFile needs the required environment variables";

          openFirewall = lib.mkEnableOption
            "Open the required ports in the firewall for the ldap service";

          ldapPort = lib.mkOption {
            type = types.port;
            default = 389;
            description = "the port for ldap";
          };

          ldapsPort = lib.mkOption {
            type = types.port;
            default = 636;
            description = "the port for ldaps";
          };
        };
      };

    };

    openFirewall = lib.mkEnableOption "Open the required ports in the firewall";

    envFile = lib.mkOption {
      type = types.str;
      description = "Path to the environment file";
    };

    dataDir = lib.mkOption {
      type = types.str;
      description = "Path to where the data will be stored";
    };

    mediaDir = lib.mkOption {
      type = types.str;
      description = "Path to the media directory";
    };

    backupDir = lib.mkOption {
      type = types.str;
      description =
        "Path to where the database will be backed up. Yes, you are required to backup your databases. Even if you think you don't, you do.";
    };

    port = lib.mkOption {
      type = types.port;
      default = 9000;
      description = "the port for http access";
    };

  };

  # We use a contianer so other services can have a different PG version
  config = lib.mkIf cfg.enable {
    containers.authentik = {
      autoStart = true;
      ephemeral = true;
      restartIfChanged = true;

      # Access to the host data
      bindMounts = {
        "${cfg.envFile}" = {
          hostPath = cfg.envFile;
          isReadOnly = true;
        };

        "${cfg.dataDir}" = {
          hostPath = cfg.dataDir;
          isReadOnly = false;
        };
        "${cfg.backupDir}" = {
          hostPath = cfg.backupDir;
          isReadOnly = false;
        };
        "/var/lib/authentik/media" = {
          hostPath = cfg.mediaDir;
          isReadOnly = false;
        };
      };

      forwardPorts = [
        {
          hostPort = cfg.port;
          protocol = "tcp";
        }
        (lib.mkIf cfg.ldap.enable {
          containerPort = 389;
          hostPort = cfg.ldap.ldapPort;
          protocol = "tcp";
        })
        (lib.mkIf cfg.ldap.enable {
          containerPort = 636;
          hostPort = cfg.ldap.ldapsPort;
          protocol = "tcp";
        })
      ];

      config = { ... }: {
        nixpkgs.pkgs = pkgs;
        imports = [ inputs.authentik-nix.nixosModules.default ];
        services = {
          authentik = {
            enable = true;
            createDatabase = true;
            environmentFile = cfg.envFile;
            settings = {
              disable_startup_analytics = true;
              avatars = "gravatar,initials";
              listen = { http = "0.0.0.0:${toString cfg.port}"; };
              paths.media = "/var/lib/authentik/media";
            };
          };

          authentik-ldap = lib.mkIf cfg.ldap.enable {
            enable = true;
            environmentFile = cfg.envFile;
          };

          # Some override of the internal services
          postgresql.dataDir = "${cfg.dataDir}/postgres";

          postgresqlBackup = {
            enable = true;
            backupAll = true;
            location = cfg.backupDir;
          };

        };

        # Create the sub folder
        systemd.tmpfiles.settings.authentik = {

          "${cfg.dataDir}/postgres" = {
            d = {
              user = "postgres";
              group = "postgres";
            };
          };

        };

        system.stateVersion = "23.11";
      };
    };

    networking.firewall = lib.mkIf cfg.openFirewall (lib.mkMerge [
      { allowedTCPPorts = [ cfg.port ]; }
      (lib.mkIf (cfg.ldap.enable && cfg.ldap.openFirewall) {
        allowedTCPPorts = [ cfg.ldap.ldapPort cfg.ldap.ldapsPort ];
        allowedUDPPorts = [ cfg.ldap.ldapPort cfg.ldap.ldapsPort ];
      })
    ]);

    # Create the folder if it doesn't exist
    systemd.tmpfiles.settings.authentik = {
      "${cfg.dataDir}" = {
        d = {
          user = "root";
          mode = "777";
        };
      };

      "${cfg.mediaDir}" = {
        d = {
          user = "root";
          mode = "777";
        };
      };

      "${cfg.backupDir}" = {
        d = {
          user = "root";
          mode = "777";
        };
      };
    };

  };
}
