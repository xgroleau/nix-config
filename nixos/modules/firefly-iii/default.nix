{
  config,
  lib,
  pkgs,
  ...
}:

let

  cfg = config.modules.firefly-iii;
  containerBackendName = config.virtualisation.oci-containers.backend;
  containerBackend = pkgs."${containerBackendName}" + "/bin/" + containerBackendName;
in
{

  options.modules.firefly-iii = with lib.types; {
    enable = lib.mkEnableOption "Enables immich, a self hosted google photo alternative";

    openFirewall = lib.mkEnableOption "Open the required ports in the firewall";

    port = lib.mkOption {
      type = types.port;
      default = 9300;
      description = "The port to use";
    };

    exporterPort = lib.mkOption {
      type = types.port;
      default = 9301;
      description = "The port to use";
    };

    dataDir = lib.mkOption {
      type = types.str;
      description = "Path to where the data will be stored";
    };

    appKeyFile = lib.mkOption {
      type = types.str;
      description = "Path to where the app key is  stored";
    };

    appUrl = lib.mkOption {
      type = types.str;
      description = "URL of the firefly-iii instance";
    };

    importerTokenFile = lib.mkOption {
      type = types.str;
      description = "Path to where the importer token is stored";
    };

    mail = lib.mkOption {
      type = types.submodule {
        options = {
          enable = lib.mkEnableOption "Enable mail support";

          host = lib.mkOption {
            type = types.str;
            description = "Host to use";
          };

          from = lib.mkOption {
            type = types.str;
            description = "Email to use to send";
          };

          username = lib.mkOption {
            type = types.str;
            description = "Username to authenticate";
          };

          passwordFile = lib.mkOption {
            type = types.str;
            description = "Path to the password file";
          };

          port = lib.mkOption {
            type = types.port;
            default = 587;
            description = "The port to use to send the email";
          };

          to = lib.mkOption {
            type = types.str;
            description = "Email to receive system notificaiton (e.g. zfs errors)";
          };
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {

    virtualisation.oci-containers.containers = {
      firefly-iii-core = {
        image = "fireflyiii/core:version-6.1.13@sha256:b69e9d94e0c068fe9381ddedb70d8ab57f5a8daecc9e1d3f629ad6b20a525473";
        environment = lib.mkMerge [
          {
            APP_URL = cfg.appUrl;
            APP_KEY_FILE = cfg.appKeyFile;
            DB_CONNECTION = "sqlite";
            TRUSTED_PROXIES = "*";
          }

          # Mail config
          (lib.mkIf cfg.mail.enable {
            MAIL_MAILER = "smtp";
            MAIL_HOST = cfg.mail.host;
            MAIL_PORT = toString cfg.mail.port;
            MAIL_FROM = cfg.mail.from;
            MAIL_USERNAME = cfg.mail.username;
            MAIL_PASSWORD_FILE = cfg.mail.passwordFile;
            MAIL_ENCRYPTION = "tls";
          })
        ];
        volumes = [
          "${cfg.dataDir}:/var/www/html/storage:rw"
          "${cfg.appKeyFile}:${cfg.appKeyFile}:ro"
        ];
        ports = [ "${toString cfg.port}:8080/tcp" ];
        extraOptions = [ "--network=firefly-iii-bridge" ];
      };

      firefly-iii-importer = {
        image = "fireflyiii/data-importer:version-1.4.5@sha256:e5d5ad021a4b61519f1917707ac7a5dc3598a0782b676f4782cd47f90c0ea49a";
        environment = {
          VANITY_URL = cfg.appUrl;
          FIREFLY_III_URL = "http://firefly-iii-core:8080";
          FIREFLY_III_ACCESS_TOKEN_FILE = cfg.importerTokenFile;
        };
        dependsOn = [ "firefly-iii-core" ];
        volumes = [ "${cfg.importerTokenFile}:${cfg.importerTokenFile}:ro" ];
        ports = [ "${toString cfg.exporterPort}:8080/tcp" ];
        extraOptions = [ "--network=firefly-iii-bridge" ];
      };
    };
    networking.firewall = {
      allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
    };

    systemd = {
      # Network creation
      services.init-firefly-iii-network = {
        description = "Create the network bridge for firefly-iii.";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig.Type = "oneshot";
        script = ''
          # Put a true at the end to prevent getting non-zero return code, which will
          # crash the whole service.
          check=$(${containerBackend} network ls | ${pkgs.gnugrep}/bin/grep "firefly-iii-bridge" || true)
          if [ -z "$check" ]; then
            ${containerBackend} network create firefly-iii-bridge
          else
               echo "firefly-iii-bridge already exists in docker"
           fi
        '';
      };

      # Folder
      tmpfiles.rules = [
        "d ${cfg.dataDir} 0777 root - - -"
        "d ${cfg.dataDir}/app 0777 root - - -"
        "d ${cfg.dataDir}/database 0777 root - - -"
        "d ${cfg.dataDir}/export 0777 root - - -"
        "d ${cfg.dataDir}/framework 0777 root - - -"
        "d ${cfg.dataDir}/framework/cache 0777 root - - -"
        "d ${cfg.dataDir}/framework/sessions 0777 root - - -"
        "d ${cfg.dataDir}/framework/views 0777 root - - -"
        "d ${cfg.dataDir}/logs 0777 root - - -"
        "d ${cfg.dataDir}/upload 0777 root - - -"

        "f ${cfg.dataDir}/storage/database/database.sqlite 0777 root - - -"
      ];
    };
  };
}
