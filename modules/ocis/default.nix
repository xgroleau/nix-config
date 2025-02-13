# Based off https://github.com/owncloud/ocis/blob/1515c77b7d3335d32d3c537f31f570121ea60063/deployments/examples/ocis_wopi/docker-compose.yml#L1
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.ocis;

  containerBackendName = config.virtualisation.oci-containers.backend;
  containerBackend = pkgs."${containerBackendName}" + "/bin/" + containerBackendName;
in
{
  options.modules.ocis = with lib.types; {
    enable = lib.mkEnableOption "OwnCloudInfiniteScale, Nextcloud but without bloat";

    openFirewall = lib.mkEnableOption "Open the required ports in the firewall";

    collabora = lib.mkOption {
      type = types.submodule {
        options = {
          enable = lib.mkEnableOption "Enables collabora with the OCIS instance, WOPISECRET envinronment variables in the environmentFiles needs to be enabled";
          wopiDomain = lib.mkOption {
            type = types.str;
            description = "URL of the WOPI instance";
          };

          wopiPort = lib.mkOption {
            type = types.port;
            default = 8880;
            description = "The port to use for the WOPI server";
          };

          collaboraDomain = lib.mkOption {
            type = types.str;
            description = "URL of the Collabora instance";
          };

          collaboraPort = lib.mkOption {
            type = types.port;
            default = 8880;
            description = "The port to use for the Collabora server";
          };
        };
      };
      default = { };
    };

    port = lib.mkOption {
      type = types.port;
      default = 9200;
      description = "The port to use";
    };

    configDir = lib.mkOption {
      type = lib.types.str;
      description = "Path to the config file";
    };

    dataDir = lib.mkOption {
      type = types.str;
      description = "Path to where the data will be stored";
    };

    environmentFiles = lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "List of environment files to pass for secrets, oidc and others";
    };

    domain = lib.mkOption {
      type = types.str;
      description = "URL of the OCIS instance, needs to be https and the same as the OpenIDConnect proxy";
    };
  };

  config = lib.mkIf cfg.enable {

    virtualisation.oci-containers = {
      containers = lib.mkMerge [
        {
          ocis = {
            autoStart = true;
            image = "owncloud/ocis:7.0.0@sha256:01812e1147aeb2e5b527f19f645326c0e4c8d701800b4546001d64d0ae1307dc";
            ports = [ "${toString cfg.port}:9200" ];
            volumes = [
              "/etc/localtime:/etc/localtime:ro"
              "${cfg.configDir}:/etc/ocis"
              "${cfg.dataDir}:/var/lib/ocis"
            ] ++ lib.optionals cfg.collabora.enable [ "${./app-registry.yaml}:/etc/ocis/app-registry.yaml" ];

            environment = lib.mkMerge [
              {
                DEMO_USERS = "false";

                PROXY_TLS = "false";
                PROXY_HTTP_ADDR = "0.0.0.0:9200";

                OCIS_INSECURE = "false";
                OCIS_URL = "https://${cfg.domain}";
                OCIS_LOG_LEVEL = "info";

                STORAGE_USERS_DRIVER = "posix";
                STORAGE_USERS_POSIX_ROOT = "/var/lib/ocis/storage/users";
                STORAGE_USERS_POSIX_WATCH_TYPE = "inotifywait";
                STORAGE_USERS_ID_CACHE_STORE = "nats-js-kv";
                STORAGE_USERS_ID_CACHE_STORE_NODES = "localhost:9233";
                STORAGE_USERS_POSIX_USE_SPACE_GROUPS = "true";

                #Tika
                SEARCH_EXTRACTOR_TYPE = "tika";
                SEARCH_EXTRACTOR_TIKA_TIKA_URL = "http://ocis-tika:9998";
                FRONTEND_FULL_TEXT_SEARCH_ENABLED = "true";
              }

              (lib.mkIf cfg.collabora.enable {
                # make the REVA gateway accessible to the app drivers
                GATEWAY_GRPC_ADDR = "0.0.0.0:9142";
                # share the registry with the ocis container
                MICRO_REGISTRY_ADDRESS = "127.0.0.1:9233";
                # make NATS available
                NATS_NATS_HOST = "0.0.0.0";
                NATS_NATS_PORT = "9233";
              })
            ];

            environmentFiles = cfg.environmentFiles;

            entrypoint = "/bin/sh";
            extraOptions = [ "--network=ocis-bridge" ];
            cmd = [
              "-c"
              "ocis init | true; ocis server"
            ];
          };

          ocis-tika = {
            autoStart = true;
            image = "apache/tika:2.9.2.1-full@sha256:ae0b86d3c4d06d8997407fcb08f31a7259fff91c43e0c1d7fffdad1e9ade3fe8";
            extraOptions = [ "--network=ocis-bridge" ];
          };
        }

        (lib.mkIf cfg.collabora.enable {
          ocis-app-provider-collabora = {
            autoStart = true;
            image = "owncloud/ocis:7.0.0@sha256:01812e1147aeb2e5b527f19f645326c0e4c8d701800b4546001d64d0ae1307dc";
            volumes = [
              "/etc/localtime:/etc/localtime:ro"
              "${cfg.configDir}:/etc/ocis"
            ];

            environmentFiles = cfg.environmentFiles;
            environment = {
              REVA_GATEWAY = "com.owncloud.api.gateway";

              APP_PROVIDER_GRPC_ADDR = "0.0.0.0:9164";
              APP_PROVIDER_EXTERNAL_ADDR = "com.owncloud.api.app-provider-collabora";
              APP_PROVIDER_SERVICE_NAME = "app-provider-collabora";
              APP_PROVIDER_DRIVER = "wopi";
              APP_PROVIDER_WOPI_APP_NAME = "Collabora";
              APP_PROVIDER_WOPI_APP_ICON_URI = "https://${cfg.collabora.collaboraDomain}/favicon.ico";
              APP_PROVIDER_WOPI_APP_URL = "https://${cfg.collabora.collaboraDomain}";
              APP_PROVIDER_WOPI_INSECURE = "false";
              APP_PROVIDER_WOPI_WOPI_SERVER_EXTERNAL_URL = "https://${cfg.collabora.wopiDomain}";
              APP_PROVIDER_WOPI_FOLDER_URL_BASE_URL = "https://${cfg.domain}";

              # share the registry with the ocis container
              MICRO_REGISTRY_ADDRESS = "ocis:9233";
            };

            extraOptions = [ "--network=ocis-bridge" ];

            entrypoint = "/bin/sh";
            cmd = [
              "-c"
              "ocis app-provider server"
            ];
          };

          ocis-wopi = {
            autoStart = true;
            image = "cs3org/wopiserver:v10.4.0@sha256:7389a17cda3fd3920ffc93a916fb64aaf9747e643e4ac381294fd5bfb2e1ebab";
            extraOptions = [ "--network=ocis-bridge" ];

            volumes = [
              "/etc/localtime:/etc/localtime:ro"
              "${./wopiserver.conf.dist}:/etc/wopi/wopiserver.conf.dist"
              "${cfg.dataDir}:/var/lib/ocis"
            ];
            environmentFiles = cfg.environmentFiles;
            environment = {
              WOPISERVER_INSECURE = "false";
              WOPISERVER_DOMAIN = cfg.collabora.wopiDomain;
            };
            ports = [ "${toString cfg.collabora.wopiPort}:8880" ];
          };

          ocis-collabora = {
            autoStart = true;
            image = "collabora/code:24.04.11.2.1@sha256:1cf62aa5db7f7e94d0b286f5acdd2ff823f1ef87fedffef1f487abcec5d30e9a";
            volumes = [
              "/etc/localtime:/etc/localtime:ro"
            ];
            extraOptions = [
              "--network=ocis-bridge"
              "--cap-add=CAP_MKNOD"
            ];
            environment = {
              aliasgroup1 = "https://${cfg.collabora.wopiDomain}:443";
              DONT_GEN_SSL_CERT = "YES";
              extra_params = "--o:ssl.enable=false --o:ssl.termination=true --o:welcome.enable=false --o:net.frame_ancestors=${cfg.domain}";
            };
            ports = [ "${toString cfg.collabora.collaboraPort}:9980" ];
          };
        })
      ];
    };

    # Network creation
    systemd.services.init-ocis-network = {
      description = "Create the network bridge for ocis.";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig.Type = "oneshot";
      script = ''
        # Put a true at the end to prevent getting non-zero return code, which will
        # crash the whole service.
        check=$(${containerBackend} network ls | ${pkgs.gnugrep}/bin/grep "ocis-bridge" || true)
        if [ -z "$check" ]; then
          ${containerBackend} network create ocis-bridge
        else
             echo "ocis-bridge already exists in docker"
         fi
      '';
    };

    # Expose ports for container
    networking.firewall = lib.mkIf cfg.openFirewall { allowedTCPPorts = [ cfg.port ]; };

    systemd.tmpfiles.settings.ocis = {
      "${cfg.dataDir}" = {
        d = {
          mode = "0777";
          user = "root";
        };
      };
      "${cfg.configDir}" = {
        d = {
          mode = "0777";
          user = "root";
        };
      };
    };
  };
}
