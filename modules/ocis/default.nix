{ config, lib, pkgs, ... }:

with lib;
with lib.my.option;
let
  cfg = config.modules.ocis;
  ocisVersion = "5.0.0-rc.3";

  tikaVersion = "2.9.1.0-full";

  containerBackendName = config.virtualisation.oci-containers.backend;

  containerBackend = pkgs."${containerBackendName}" + "/bin/"
    + containerBackendName;
in {
  options.modules.ocis = with types; {
    enable =
      mkEnableOption "OwnCloudInfiniteScale, Nextcloud but without bloat";

    collabora = mkEnableOption
      "Enables collabora with the OCIS instance, WOPISECRET envinronment variables in the environmentFiles needs to be enabled";

    openFirewall = mkBoolOpt' false "Open the required ports in the firewall";

    port = mkOpt' types.port 9200 "the port to use";

    configDir = mkReq types.str "Path to the config file";

    dataDir = mkReq types.str "Path to where the data will be stored";

    environmentFiles = mkOpt' (types.listOf types.str) [ ]
      "List of environment files to pass for secrets, oidc and others";

    url = mkReq types.str
      "URL of the OCIS instance, needs to be https and the same as the OpenIDConnect proxy";
  };

  config = mkIf cfg.enable {

    virtualisation.oci-containers = {
      containers = lib.mkMerge [
        {
          ocis = {
            autoStart = true;
            image = "owncloud/ocis:${ocisVersion}";
            ports = [ "${toString cfg.port}:9200" ];
            volumes =
              [ "${cfg.configDir}:/etc/ocis" "${cfg.dataDir}:/var/lib/ocis" ];

            environment = lib.mkMerge [
              {
                DEMO_USERS = "false";

                PROXY_TLS = "false";
                PROXY_HTTP_ADDR = "0.0.0.0:9200";

                OCIS_INSECURE = "false";
                OCIS_URL = cfg.url;
                OCIS_LOG_LEVEL = "info";

                #Tika
                SEARCH_EXTRACTOR_TYPE = "tika";
                SEARCH_EXTRACTOR_TIKA_TIKA_URL = "http://ocis-tika:9998";
                FRONTEND_FULL_TEXT_SEARCH_ENABLED = "true";
              }

              (lib.mkIf cfg.collabora {
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
            cmd = [ "-c" "ocis init | true; ocis server" ];
          };

          ocis-tika = {
            autoStart = true;
            image = "apache/tika:${tikaVersion}";
            extraOptions = [ "--network=ocis-bridge" ];
          };
        }

        (lib.mkIf cfg.collabora {
          ocis-app-provider-collabora = {
            autoStart = true;
            image = "owncloud/ocis:${ocisVersion}";
            volumes = [ "${cfg.configDir}:/etc/ocis" ];

            environmentFiles = cfg.environmentFiles;
            environment = {
              REVA_GATEWAY = "com.owncloud.api.gateway";

              APP_PROVIDER_GRPC_ADDR = "0.0.0.0:9164";
              APP_PROVIDER_EXTERNAL_ADDR = "ocis-app-provider-collabora:9164";
              APP_PROVIDER_SERVICE_NAME = "app-provider-collabora";
              APP_PROVIDER_DRIVER = "wopi";
              APP_PROVIDER_WOPI_APP_NAME = "Collabora";
              APP_PROVIDER_WOPI_APP_ICON_URI =
                "http://ocis-collabora:9980/favicon.ico";
              APP_PROVIDER_WOPI_APP_URL = "http://ocis-collabora:9980";
              APP_PROVIDER_WOPI_INSECURE = "true";
              APP_PROVIDER_WOPI_WOPI_SERVER_EXTERNAL_URL = "http://ocis-wopi";
              APP_PROVIDER_WOPI_FOLDER_URL_BASE_URL = cfg.url;

              # share the registry with the ocis container
              MICRO_REGISTRY_ADDRESS = "ocis:9233";
            };

            extraOptions = [ "--network=ocis-bridge" ];

            entrypoint = "/bin/sh";
            cmd = [ "-c" "ocis app-provider server" ];
          };

          ocis-wopi = {
            autoStart = true;
            image = "cs3org/wopiserver:v10.3.1";
            extraOptions = [ "--network=ocis-bridge" ];

            volumes = [
              "${./wopiserver.conf.dist}:/etc/wopi/wopiserver.conf.dist"
              "${cfg.dataDir}:/var/lib/ocis"
            ];
            environmentFiles = cfg.environmentFiles;
            environment = {
              WOPISERVER_INSECURE = "true";
              WOPISERVER_DOMAIN = "wopi";
            };
          };

          ocis-collabora = {
            autoStart = true;
            image = "collabora/code:23.05.5.2.1";
            extraOptions = [ "--network=ocis-bridge" "--cap-add=CAP_MKNOD" ];
            environment = {
              DONT_GEN_SSL_CERT = "YES";
              extra_params =
                "--o:ssl.enable=false --o:ssl.termination=false --o:welcome.enable=false --o:net.frame_ancestors=${cfg.url}";
            };
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
    networking.firewall =
      mkIf cfg.openFirewall { allowedTCPPorts = [ cfg.port ]; };

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
