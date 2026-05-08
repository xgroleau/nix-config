{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.paperlessNgx;
  postgresqlPort = 5433;
in
{

  imports = [ ];

  options.modules.paperlessNgx = with lib.types; {
    enable = lib.mkEnableOption ''
      Enables the paperless-ngx module, uses a nixos container under the hood so the postges db is a seperated service.
       Also uses ephemeral container, so you need to pass the media directory'';

    openFirewall = lib.mkEnableOption "Open the required ports in the firewall";

    url = lib.mkOption {
      type = types.str;
      description = "Url of paperless";
    };

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
          networking.useHostResolvConf = true;

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
                PAPERLESS_URL = cfg.url;
                PAPERLESS_APPS = "allauth.socialaccount.providers.openid_connect";
                PAPERLESS_CONSUMER_IGNORE_PATTERN = [
                  ".DS_STORE/*"
                  "desktop.ini"
                ];
                PAPERLESS_OCR_LANGUAGE = "fra+eng";
                PAPERLESS_FILENAME_FORMAT = "{{ created_year }}/{{ document_type }}/{{ correspondent }}/{{ title }}";
                PAPERLESS_DBPORT = postgresqlPort;
                PAPERLESS_OCR_USER_ARGS = {
                  optimize = 1;
                  pdfa_image_compression = "lossless";
                };
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

      # Allow to write to backupdir
      users.postgres = lib.mkDefault {
        isSystemUser = true;
        group = "postgres";
        uid = config.ids.uids.postgres;
      };
      groups.postgres = lib.mkDefault {
        gid = config.ids.gids.postgres;
      };
    };

    # Authentik blueprint — declares the OAuth2 provider + application for
    # paperless. Resolved client credentials come from authentik's env file
    # (must contain PAPERLESS_OIDC_CLIENT_ID and PAPERLESS_OIDC_CLIENT_SECRET).
    modules.authentik.blueprints.paperless = ''
      version: 1
      metadata:
        name: paperless
        labels:
          blueprints.goauthentik.io/instantiate: "true"

      entries:
        - id: paperless-provider
          model: authentik_providers_oauth2.oauth2provider
          identifiers:
            name: Provider for Paperless-ngx
          attrs:
            name: Provider for Paperless-ngx
            client_type: confidential
            client_id: !Env PAPERLESS_OIDC_CLIENT_ID
            client_secret: !Env PAPERLESS_OIDC_CLIENT_SECRET

            authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-explicit-consent]]
            invalidation_flow:  !Find [authentik_flows.flow, [slug, default-provider-invalidation-flow]]

            access_code_validity:    minutes=1
            access_token_validity:   minutes=5
            refresh_token_validity:  days=30
            refresh_token_threshold: seconds=0

            include_claims_in_id_token: true
            issuer_mode: per_provider
            sub_mode: user_email
            logout_method: backchannel

            signing_key: !Find [authentik_crypto.certificatekeypair, [name, authentik Self-signed Certificate]]

            redirect_uris:
              - matching_mode: strict
                url: "${cfg.url}/accounts/oidc/authentik/login/callback/"

            property_mappings:
              - !Find [authentik_providers_oauth2.scopemapping, [scope_name, openid]]
              - !Find [authentik_providers_oauth2.scopemapping, [scope_name, email]]
              - !Find [authentik_providers_oauth2.scopemapping, [scope_name, profile]]
              - !Find [authentik_providers_oauth2.scopemapping, [scope_name, offline_access]]

        - id: paperless-app
          model: authentik_core.application
          identifiers:
            slug: paperless
          attrs:
            name: Paperless-ngx
            slug: paperless
            provider: !KeyOf paperless-provider
            group: cloud
            meta_description: Document management software
            meta_launch_url: ${cfg.url}
            open_in_new_tab: true
            policy_engine_mode: any
    '';

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
          user = "postgres";
          group = "postgres";
          mode = "700";
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
