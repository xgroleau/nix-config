{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.miniflux;
  postgresqlPort = 5434;
in
{

  imports = [ ];

  options.modules.miniflux = with lib.types; {
    enable = lib.mkEnableOption ''
      Enables the miniflux module, uses a nixos container under the hood so the postges db is a seperated service.
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
          networking.useHostResolvConf = true;

          # db setup port
          systemd.services.miniflux-dbsetup.serviceConfig.Environment = [
            "PGHOST=/run/postgresql"
            "PGPORT=${toString postgresqlPort}"
          ];

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
                DATABASE_URL = lib.mkForce "user=miniflux host=/run/postgresql port=${toString postgresqlPort} dbname=miniflux";
              };
            };

            # Some override of the internal services
            postgresql = {
              dataDir = "${cfg.dataDir}/postgres";
              settings.port = postgresqlPort;
            };
            postgresqlBackup = {
              enable = true;
              backupAll = true;
              location = cfg.backupDir;
            };
          };

          systemd.services.postgresqlBackup.environment = {
            PGHOST = "/run/postgresql";
            PGPORT = toString postgresqlPort;
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

    modules.authentik.blueprints.miniflux = lib.mkIf config.modules.authentik.enable ''
      version: 1
      entries:
        - id: miniflux-provider
          model: authentik_providers_oauth2.oauth2provider
          identifiers:
            name: miniflux
          attrs:
            name: miniflux
            client_type: confidential
            client_id: !Env MINIFLUX_OIDC_CLIENT_ID
            client_secret: !Env MINIFLUX_OIDC_CLIENT_SECRET

            authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-explicit-consent]]
            invalidation_flow:  !Find [authentik_flows.flow, [slug, default-provider-invalidation-flow]]

            access_code_validity:    minutes=1
            access_token_validity:   minutes=5
            refresh_token_validity:  days=30
            refresh_token_threshold: seconds=0

            include_claims_in_id_token: true
            issuer_mode: per_provider
            sub_mode: hashed_user_id
            logout_method: backchannel

            signing_key: !Find [authentik_crypto.certificatekeypair, [name, authentik Self-signed Certificate]]

            redirect_uris:
              - matching_mode: strict
                url: "${cfg.url}/oauth2/oidc/callback"

            property_mappings:
              - !Find [authentik_providers_oauth2.scopemapping, [scope_name, openid]]
              - !Find [authentik_providers_oauth2.scopemapping, [scope_name, email]]
              - !Find [authentik_providers_oauth2.scopemapping, [scope_name, profile]]

        - id: miniflux-app
          model: authentik_core.application
          identifiers:
            slug: miniflux
          attrs:
            name: miniflux
            slug: miniflux
            provider: !KeyOf miniflux-provider
            group: cloud
            meta_description: RSS reader
            meta_launch_url: ${cfg.url}
            meta_icon: ${cfg.url}/favicon.ico
            open_in_new_tab: true
            policy_engine_mode: any

        # Gate access to the app on membership in the `cloud` group
        - id: miniflux-cloud-binding
          model: authentik_policies.policybinding
          identifiers:
            target: !KeyOf miniflux-app
            order: 0
          attrs:
            enabled: true
            order: 0
            negate: false
            failure_result: false
            timeout: 30
            group: !Find [authentik_core.group, [name, cloud]]
    '';

    # Allow to write to backupdir
    users.users.postgres = lib.mkDefault {
      isSystemUser = true;
      group = "postgres";
      uid = config.ids.uids.postgres;
    };
    users.groups.postgres = lib.mkDefault {
      gid = config.ids.gids.postgres;
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
          user = "postgres";
          group = "postgres";
          mode = "700";
        };
      };
    };
  };
}
