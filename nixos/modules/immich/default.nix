{
  config,
  lib,
  pkgs,
  ...
}:

let

  cfg = config.modules.immich;

  # All immich containers write as this identity
  immichId = 971;

  containerBackendName = config.virtualisation.oci-containers.backend;

  containerBackend = pkgs."${containerBackendName}" + "/bin/" + containerBackendName;
in
{

  options.modules.immich = with lib.types; {
    enable = lib.mkEnableOption "Enables immich, a self hosted google photo alternative";

    openFirewall = lib.mkEnableOption "Open the required ports in the firewall";

    port = lib.mkOption {
      type = types.port;
      default = 9300;
      description = "The port to use";
    };

    url = lib.mkOption {
      type = types.str;
      description = "Public URL of immich (used for OIDC redirect URIs and launcher).";
    };

    configDir = lib.mkOption {
      type = lib.types.str;
      description = "Path to the config file";
    };

    dataDir = lib.mkOption {
      type = types.str;
      description = "Path to where the data will be stored";
    };

    databaseDir = lib.mkOption {
      type = types.str;
      description = "Path to where the database will be stored";
    };

    backupDir = lib.mkOption {
      type = types.str;
      description = "Path to where the database will be backed up. Yes, you are required to backup your databases. Even if you think you don't, you do.";
    };

    envFile = lib.mkOption {
      type = types.str;
      description = ''
        Path to where the secrets environment file is.
        Needs to contain the following environment values
          DB_PASSWORD="YYYY"
          POSTGRES_PASSWORD="YYYY"
      '';
    };
  };

  config = lib.mkIf cfg.enable {

    users.deterministicIds.immich = {
      uid = immichId;
      gid = immichId;
    };
    users.users.immich = {
      group = "immich";
      isSystemUser = true;
    };
    users.groups.immich = { };

    virtualisation.oci-containers.containers = {
      immich-server = {
        autoStart = true;
        image = "ghcr.io/imagegenius/immich:3.0.3@sha256:c6451b4defc1b26cbb9727ebcb2f7c66ac11b87a3999bf78c64741f8bc3c39d8";
        volumes = [
          "/etc/localtime:/etc/localtime:ro"
          "${cfg.configDir}:/config"
          "${cfg.dataDir}:/photos"
        ];

        environment = {
          PUID = toString immichId;
          PGID = toString immichId;

          # Redis
          REDIS_HOSTNAME = "immich-valkey";
          REDIS_PORT = "6379";

          # postgres
          DB_HOSTNAME = "immich-postgres";
          DB_USERNAME = "postgres";
          DB_PORT = "5432";
          DB_DATABASE_NAME = "immich";

          # Currently noml
          MACHINE_LEARNING_WORKERS = "1";
          MACHINE_LEARNING_WORKER_TIMEOUT = "120";
        };

        environmentFiles = [ cfg.envFile ];
        ports = [ "${toString cfg.port}:8080" ];
        dependsOn = [
          "immich-postgres"
          "immich-valkey"
        ];
        extraOptions = [ "--network=immich-bridge" ];
      };

      immich-valkey = {
        autoStart = true;
        image = "valkey/valkey:8-bookworm@sha256:fea8b3e67b15729d4bb70589eb03367bab9ad1ee89c876f54327fc7c6e618571";
        environmentFiles = [ cfg.envFile ];
        extraOptions = [ "--network=immich-bridge" ];
      };

      immich-postgres = {
        autoStart = true;
        image = "ghcr.io/immich-app/postgres:16-vectorchord0.4.3-pgvectors0.3.0@sha256:0851d187e1f512300b3fcf7911641aa94075a3bfe457f2600ec8637ca1cb9139";

        # The official postgres images support running as an arbitrary uid,
        # the data dir must be owned by it
        user = "${toString immichId}:${toString immichId}";

        volumes = [
          "/etc/localtime:/etc/localtime:ro"
          "${cfg.databaseDir}:/var/lib/postgresql/data"
        ];

        environment = {
          POSTGRES_USER = "postgres";
          POSTGRES_DB = "immich";
          DB_STORAGE_TYPE = "HDD";
        };

        environmentFiles = [ cfg.envFile ];

        extraOptions = [ "--network=immich-bridge" ];
      };
    };

    systemd = {
      # Backing up
      timers.immich-postgres-backup = {
        wantedBy = [ "timers.target" ];
        partOf = [ "immich-postgres-backup.service" ];
        timerConfig = {
          RandomizedDelaySec = "1h";
          OnCalendar = [ "*-*-* 02:00:00" ];
        };
      };

      services.immich-postgres-backup = {
        description = "Creates a backup for the immich database";
        wantedBy = [ "multi-user.target" ];
        path = with pkgs; [
          containerBackend
          gzip
        ];

        script = ''
          ${containerBackend} exec -t immich-postgres pg_dumpall -c -U postgres | gzip > "${cfg.backupDir}/immich.sql.gz"
        '';

        serviceConfig = {
          User = "root";
          Type = "oneshot";
        };
      };

      # Network creation
      services.init-immich-network = {
        description = "Create the network bridge for immich.";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig.Type = "oneshot";
        script = ''
          # Put a true at the end to prevent getting non-zero return code, which will
          # crash the whole service.
          check=$(${containerBackend} network ls | ${pkgs.gnugrep}/bin/grep "immich-bridge" || true)
          if [ -z "$check" ]; then
            ${containerBackend} network create immich-bridge
          else
               echo "immich-bridge already exists in docker"
           fi
        '';
      };
    };

    networking.firewall = {
      allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
      interfaces."podman+".allowedUDPPorts = [ 53 ];
    };

    systemd.tmpfiles.settings.immich = {
      "${cfg.configDir}" = {
        d = {
          mode = "0700";
          user = "immich";
          group = "immich";
        };
      };
      "${cfg.dataDir}" = {
        d = {
          mode = "0700";
          user = "immich";
          group = "immich";
        };
      };
      "${cfg.databaseDir}" = {
        d = {
          mode = "0700";
          user = "immich";
          group = "immich";
        };
      };

      "${cfg.backupDir}" = {
        d = {
          mode = "0700";
          user = "root";
          group = "root";
        };
      };
    };

    modules.authentik.blueprints.immich = lib.mkIf config.modules.authentik.enable ''
      version: 1
      metadata:
        name: immich
      entries:
        - id: immich-provider
          model: authentik_providers_oauth2.oauth2provider
          identifiers:
            name: Immich
          attrs:
            name: Immich
            client_type: confidential
            client_id: !Env IMMICH_OIDC_CLIENT_ID
            client_secret: !Env IMMICH_OIDC_CLIENT_SECRET

            authentication_flow: !Find [authentik_flows.flow, [slug, default-authentication-flow]]
            authorization_flow:  !Find [authentik_flows.flow, [slug, default-provider-authorization-explicit-consent]]
            invalidation_flow:   !Find [authentik_flows.flow, [slug, default-provider-invalidation-flow]]

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
              # Mobile app uses a custom URL scheme
              - matching_mode: strict
                url: "app.immich:///oauth-callback"
              - matching_mode: strict
                url: "${cfg.url}/auth/login"
              - matching_mode: strict
                url: "${cfg.url}/oauth-callback"

            property_mappings:
              - !Find [authentik_providers_oauth2.scopemapping, [scope_name, openid]]
              - !Find [authentik_providers_oauth2.scopemapping, [scope_name, email]]
              - !Find [authentik_providers_oauth2.scopemapping, [scope_name, profile]]
              - !Find [authentik_providers_oauth2.scopemapping, [scope_name, offline_access]]

        - id: immich-app
          model: authentik_core.application
          identifiers:
            slug: immich
          attrs:
            name: Immich
            slug: immich
            provider: !KeyOf immich-provider
            group: cloud
            meta_description: Cloud backup for photo (e.g. Google Photos)
            meta_launch_url: ${cfg.url}
            meta_icon: https://cdn.jsdelivr.net/gh/selfhst/icons/svg/immich.svg
            open_in_new_tab: true
            policy_engine_mode: any

        # Gate access to the app on membership in the `cloud` group
        - id: immich-cloud-binding
          model: authentik_policies.policybinding
          identifiers:
            target: !KeyOf immich-app
            order: 0
          attrs:
            enabled: true
            order: 0
            negate: false
            failure_result: false
            timeout: 30
            group: !Find [authentik_core.group, [name, cloud]]
    '';
  };
}
