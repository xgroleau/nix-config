# https://github.com/opencloud-eu/opencloud/blob/main/deployments/examples/opencloud_full/keycloak.yml
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.opencloud;

  containerBackendName = config.virtualisation.oci-containers.backend;
  containerBackend = pkgs."${containerBackendName}" + "/bin/" + containerBackendName;
in
{
  options.modules.opencloud = with lib.types; {
    enable = lib.mkEnableOption "OpenCloud, Nextcloud but without bloat";

    openFirewall = lib.mkEnableOption "Open the required ports in the firewall";

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
      description = "URL of the Opencloud instance, needs to be https and the same as the OpenIDConnect proxy";
    };
  };

  config = lib.mkIf cfg.enable {

    virtualisation.oci-containers = {
      containers = lib.mkMerge [
        {
          opencloud = {
            autoStart = true;
            image = "opencloudeu/opencloud:2.0.3@sha256:660d12173e21e3fbcf6f6b5c0a197e239285d5abc1e44cacde77124263080a51";
            ports = [ "${toString cfg.port}:9200" ];
            volumes = [
              "/etc/localtime:/etc/localtime:ro"
              "${cfg.configDir}:/etc/opencloud"
              "${./csp.yaml}:/etc/opencloud/csp.yaml"
              "${./proxy.yaml}:/etc/opencloud/proxy.yaml"
              "${./app-registry.yaml}:/etc/opencloud/app-registry.yaml"
              "${cfg.dataDir}:/var/lib/opencloud"
            ];

            environment = {
              IDM_CREATE_DEMO_USERS = "false";

              PROXY_TLS = "false";
              PROXY_HTTP_ADDR = "0.0.0.0:9200";
              START_ADDITIONAL_SERVICES = "notifications";

              OC_INSECURE = "false";
              OC_URL = "https://${cfg.domain}";
              OC_LOG_LEVEL = "info";

              STORAGE_USERS_POSIX_WATCH_FS = "true";
              GATEWAY_GRPC_ADDR = "0.0.0.0:9142";
              MICRO_REGISTRY_ADDRESS = "127.0.0.1:9233";
              NATS_NATS_HOST = "0.0.0.0";
              NATS_NATS_PORT = "9233";

              #Tika
              SEARCH_EXTRACTOR_TYPE = "tika";
              SEARCH_EXTRACTOR_TIKA_TIKA_URL = "http://opencloud-tika:9998";
              FRONTEND_FULL_TEXT_SEARCH_ENABLED = "true";
            };

            environmentFiles = cfg.environmentFiles;

            entrypoint = "/bin/sh";
            extraOptions = [ "--network=opencloud-bridge" ];
            cmd = [
              "-c"
              "opencloud init | true; opencloud server"
            ];
          };

          opencloud-tika = {
            autoStart = true;
            image = "apache/tika:3.2.1.0-full@sha256:94ed7a7758da63b3fd90d0db2378a6c04698f6fb3a807e92ac5dc24f915257fc";
            extraOptions = [ "--network=opencloud-bridge" ];
          };
        }
      ];
    };

    # Network creation
    systemd.services.init-opencloud-network = {
      description = "Create the network bridge for opencloud.";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig.Type = "oneshot";
      script = ''
        # Put a true at the end to prevent getting non-zero return code, which will
        # crash the whole service.
        check=$(${containerBackend} network ls | ${pkgs.gnugrep}/bin/grep "opencloud-bridge" || true)
        if [ -z "$check" ]; then
          ${containerBackend} network create opencloud-bridge
        else
             echo "opencloud-bridge already exists"
         fi
      '';
    };

    # Expose ports for container
    networking.firewall = lib.mkIf cfg.openFirewall { allowedTCPPorts = [ cfg.port ]; };

    systemd.tmpfiles.settings.opencloud = {
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
