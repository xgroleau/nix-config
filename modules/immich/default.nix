{ config, lib, pkgs, ... }:

with lib;
with lib.my.option;
let

  cfg = config.modules.immich;
  immichImage = "ghcr.io/imagegenius/immich";
  immichVersion = "1.93.3-noml";
  immichHash =
    "sha256:440bfe850b36b6e41437f314af7441de3dd1874591c889b1adf3986ae86ff82b";

  postgresImage = "tensorchord/pgvecto-rs";
  postgresVersion = "pg16-v0.1.11";
  postgresHash =
    "sha256:6102a989f03361b4f1f36057888405597bc5b9851aa237cc3216f40c23f9853a";

  redisImage = "redis";
  redisVersion = "6.2-alpine";
  redisHash =
    "sha256:c5a607fb6e1bb15d32bbcf14db22787d19e428d59e31a5da67511b49bb0f1ccc";

  containerBackendName = config.virtualisation.oci-containers.backend;

  containerBackend = pkgs."${containerBackendName}" + "/bin/"
    + containerBackendName;
in {

  options.modules.immich = with types; {
    enable =
      mkEnableOption "Enables immich, a self hosted google photo alternative";

    openFirewall = mkBoolOpt' false "Open the required ports in the firewall";

    port = mkOpt' types.port 9300 "the port to use";

    configDir = mkReq types.str "Path to the config file";

    dataDir = mkReq types.str "Path to where the data will be stored";

    backupDir = mkReq types.str
      "Path to where the database will be backed up. Yes, you are required to backup your databases. Even if you think you don't, you do.";

    databaseDir = mkReq types.str "Path to where the database will be stored";

    envFile = mkReq types.str ''
      Path to where the secrets environment file is.
      Needs to contain the following environment values
        DB_PASSWORD="YYYY"
        POSTGRES_PASSWORD="YYYY"
    '';

  };

  config = mkIf cfg.enable {

    virtualisation.oci-containers.containers = {
      immich-server = {
        autoStart = true;
        image = "${immichImage}:${immichVersion}@${immichHash}";
        volumes = [
          "/etc/localtime:/etc/localtime:ro"
          "${cfg.configDir}:/config"
          "${cfg.dataDir}:/photos"
        ];

        environment = {
          PUID = "1000";
          PGID = "1000";

          # Redis
          REDIS_HOSTNAME = "immich-redis";
          REDIS_PORT = "6379";

          # postgres
          DB_HOSTNAME = "immich-postgres";
          DB_USERNAME = "postgres";
          DB_PORT = "5432";
          DB_DATABASE_NAME = "immich";

          # Currently noml
          # MACHINE_LEARNING_WORKERS = "1";
          # MACHINE_LEARNING_WORKER_TIMEout = "120";
        };

        environmentFiles = [ cfg.envFile ];
        ports = [ "${toString cfg.port}:8080" ];
        dependsOn = [ "immich-postgres" "immich-redis" ];
        extraOptions = [ "--network=immich-bridge" ];
      };

      immich-redis = {
        autoStart = true;
        image = "${redisImage}:${redisVersion}@${redisHash}";
        environmentFiles = [ cfg.envFile ];
        extraOptions = [ "--network=immich-bridge" ];
      };

      immich-postgres = {
        autoStart = true;
        image = "${postgresImage}:${postgresVersion}@${postgresHash}";

        volumes = [
          "/etc/localtime:/etc/localtime:ro"
          "${cfg.databaseDir}:/var/lib/postgresql/data"
        ];

        environment = {
          POSTGRES_USER = "postgres";
          POSTGRES_DB = "immich";
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
        path = with pkgs; [ containerBackend gzip ];

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
      allowedTCPPorts = mkIf cfg.openFirewall [ cfg.port ];
      interfaces."podman+".allowedUDPPorts = [ 53 ];
    };

    systemd.tmpfiles.settings.immich = {
      "${cfg.configDir}" = {
        d = {
          mode = "0755";
          user = "root";
        };
      };
      "${cfg.dataDir}" = {
        d = {
          mode = "0755";
          user = "root";
        };
      };
      "${cfg.databaseDir}" = {
        d = {
          mode = "0755";
          user = "root";
        };
      };

      "${cfg.backupDir}" = {
        d = {
          mode = "0755";
          user = "root";
        };
      };
    };
  };
}
