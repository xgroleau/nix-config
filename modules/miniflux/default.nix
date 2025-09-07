{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.modules.miniflux;
in
{

  imports = [ ];

  options.modules.miniflux = with lib.types; {
    enable = lib.mkEnableOption ''
      Enables the miniflux-ngx module, uses a nixos container under the hood so the postges db is a seperated service.
       Also uses ephemeral container'';

    openFirewall = lib.mkEnableOption "Open the required ports in the firewall";

    url = lib.mkOption {
      type = types.str;
      description = "Url of miniflux";
    };

    envFile = lib.mkOption {
      type = types.str;
      description = "Path to the environment file";
    };

    dataDir = lib.mkOption {
      type = types.str;
      description = "Path to where the data will be stored";
    };

    backupDir = lib.mkOption {
      type = types.str;
      description = "Path to where the database will be backed up. Yes, you are required to backup your databases. Even if you think you don't, you do.";
    };

    port = lib.mkOption {
      type = types.port;
      default = 8080;
      description = "the port for http access";
    };

  };

  # We use a contianer so other services can have a different PG version
  config = lib.mkIf cfg.enable {
    containers.miniflux = {
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

        "${cfg.backupDir}" = {
          hostPath = cfg.backupDir;
          isReadOnly = false;
        };
      };

      config =
        { ... }:
        {
          nixpkgs.pkgs = pkgs;

          services = {
            miniflux = {
              enable = true;
              adminCredentialsFile = cfg.envFile;
              createDatabaseLocally = true;
              config = {
                PORT = cfg.port;
                BASE_URL = cfg.url;

                CLEANUP_FREQUENCY = 48;

                # Change the default port value
                DATABASE_URL = lib.mkForce "user=miniflux host=/run/postgresql port=5434 dbname=miniflux";
              };
            };

            # Some override of the internal services
            postgresql = {
              dataDir = "${cfg.dataDir}/postgres";
              settings.port = 5434;
            };
            postgresqlBackup = {
              enable = true;
              backupAll = true;
              location = cfg.backupDir;
            };
          };

          # Create the sub folder
          systemd.tmpfiles.settings.miniflux = {
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

    # Create the folder if it doesn't exist
    systemd.tmpfiles.settings.miniflux = {
      "${cfg.dataDir}" = {
        d = {
          user = "root";
          group = "root";
          mode = "711";
        };
      };

      "${cfg.backupDir}" = {
        d = {
          user = "root";
          group = "root";
          mode = "777";
        };
      };

    };
  };
}
