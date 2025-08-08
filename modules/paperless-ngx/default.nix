{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.modules.paperlessNgx;
in
{

  imports = [ ];

  options.modules.paperlessNgx = with lib.types; {
    enable = lib.mkEnableOption ''
      Enables the paperless-ngx module, uses a nixos container under the hood so the postges db is a seperated service.
       Also uses ephemeral container, so you need to pass the media directory'';

    openFirewall = lib.mkEnableOption "Open the required ports in the firewall";

    envFile = lib.mkOption {
      type = types.str;
      description = "Path to the environment file";
    };

    dataDir = lib.mkOption {
      type = types.str;
      description = "Path to where the data will be stored";
    };

    consumptionDir = lib.mkOption {
      type = types.str;
      description = "Path to where the data will be consumed";
    };

    mediaDir = lib.mkOption {
      type = types.str;
      description = "Path to the media directory";
    };

    backupDir = lib.mkOption {
      type = types.str;
      description = "Path to where the database will be backed up. Yes, you are required to backup your databases. Even if you think you don't, you do.";
    };

    port = lib.mkOption {
      type = types.port;
      default = 28981;
      description = "the port for http access";
    };

  };

  # We use a contianer so other services can have a different PG version
  config = lib.mkIf cfg.enable {
    containers.paperlessNgx = {
      autoStart = true;
      ephemeral = true;
      restartIfChanged = true;
      privateUsers = "identity";

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

        "${cfg.consumptionDir}" = {
          hostPath = cfg.consumptionDir;
          isReadOnly = false;
        };
        "${cfg.backupDir}" = {
          hostPath = cfg.backupDir;
          isReadOnly = false;
        };
        "${cfg.mediaDir}" = {
          hostPath = cfg.mediaDir;
          isReadOnly = false;
        };
      };

      config =
        { ... }:
        {
          nixpkgs.pkgs = pkgs;

          services = {
            paperless = {
              enable = true;
              address = "::";
              port = cfg.port;
              environmentFile = cfg.envFile;
              dataDir = cfg.dataDir;
              mediaDir = cfg.mediaDir;
              consumptionDir = cfg.consumptionDir;

              consumptionDirIsPublic = true;
              database.createLocally = true;
              configureTika = true;

              settings = {
                PAPERLESS_APPS = "allauth.socialaccount.providers.openid_connect";
                PAPERLESS_CONSUMER_IGNORE_PATTERN = [
                  ".DS_STORE/*"
                  "desktop.ini"
                ];
                PAPERLESS_OCR_LANGUAGE = "fra+eng";
                PAPERLESS_DBPORT = 5433;
                PAPERLESS_OCR_USER_ARGS = {
                  optimize = 1;
                  pdfa_image_compression = "lossless";
                };
              };
            };

            # Some override of the internal services
            postgresql = {
              dataDir = "${cfg.dataDir}/postgres";
              settings.port = 5433;
            };
            postgresqlBackup = {
              enable = true;
              backupAll = true;
              location = cfg.backupDir;
            };
          };

          # Create the sub folder
          systemd.tmpfiles.settings.paperlessNgx = {
            "${cfg.dataDir}/postgres" = {
              d = {
                user = "postgres";
                group = "postgres";
                mode = "750";
              };
            };
          };

          system.stateVersion = "23.11";
        };
    };

    networking = {
      firewall = lib.mkIf cfg.openFirewall (
        lib.mkMerge [
          { allowedTCPPorts = [ cfg.port ]; }
        ]
      );
    };

    users = {
      users.paperless = {
        group = "paperless";
        uid = config.ids.uids.paperless;
        home = cfg.dataDir;
      };

      groups.paperless = {
        gid = config.ids.gids.paperless;
      };
    };

    # Create the folder if it doesn't exist
    systemd.tmpfiles.settings.paperlessNgx = {
      "${cfg.dataDir}" = {
        d = {
          user = "paperless";
          group = "paperless";
          mode = "777";
        };
      };

      "${cfg.mediaDir}" = {
        d = {
          user = "paperless";
          group = "paperless";
          mode = "750";
        };
      };

      "${cfg.backupDir}" = {
        d = {
          user = "paperless";
          group = "paperless";
          mode = "750";
        };
      };

      "${cfg.consumptionDir}" = {
        d = {
          user = "paperless";
          group = "paperless";
          mode = "750";
        };
      };
    };
  };
}
