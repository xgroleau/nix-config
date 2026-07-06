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
  openCloudImage = "opencloudeu/opencloud:7.2.1@sha256:85a4d3ceb61626bdca9fc52c3c290692d0b07b7ba2e8315b1cd67ddedfc371a6";
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
      description = "Domain of the Opencloud instance, needs to be https and the same as the OpenIDConnect proxy";
    };

    collabora = lib.mkOption {
      type = types.submodule {
        options = {
          enable = lib.mkEnableOption "Enables collabora with the opencloud instance";

          collaboraDomain = lib.mkOption {
            type = types.str;
            description = "Domain of the Collabora instance";
          };

          collaboraPort = lib.mkOption {
            type = types.port;
            default = 9300;
            description = "The port to use for colllabora ";
          };

          companionDomain = lib.mkOption {
            type = types.str;
            description = "domain of the companion instance";
          };

          companionPort = lib.mkOption {
            type = types.port;
            default = 9980;
            description = "The port to use for companion";
          };
        };
      };
      default = { };
    };
  };

  config = lib.mkIf cfg.enable {

    virtualisation.oci-containers = {
      containers = lib.mkMerge [
        {
          opencloud = {
            autoStart = true;
            image = openCloudImage;
            ports = [ "${toString cfg.port}:9200" ];
            volumes = [
              "/etc/localtime:/etc/localtime:ro"
              "${cfg.configDir}:/etc/opencloud"
              "${./csp.yaml}:/etc/opencloud/csp.yaml"
              "${./proxy.yaml}:/etc/opencloud/proxy.yaml"
              "${./app-registry.yaml}:/etc/opencloud/app-registry.yaml"
              "${cfg.dataDir}:/var/lib/opencloud"
            ];
            networks = [ "opencloud-bridge" ];

            entrypoint = "/bin/sh";
            cmd = [
              "-c"
              "opencloud init | true; opencloud server"
            ];

            environmentFiles = cfg.environmentFiles;
            environment = lib.mkMerge [
              {
                IDM_CREATE_DEMO_USERS = "false";

                PROXY_TLS = "false";
                PROXY_HTTP_ADDR = "0.0.0.0:9200";
                START_ADDITIONAL_SERVICES = "notifications";

                OC_INSECURE = "false";
                OC_URL = "https://${cfg.domain}";
                # OC_LOG_LEVEL = "info";

                PROXY_CSP_CONFIG_FILE_LOCATION = "/etc/opencloud/csp.yaml";
                STORAGE_USERS_POSIX_WATCH_FS = "true";

                #Tika
                SEARCH_EXTRACTOR_TYPE = "tika";
                SEARCH_EXTRACTOR_TIKA_TIKA_URL = "http://opencloud-tika:9998";
                FRONTEND_FULL_TEXT_SEARCH_ENABLED = "true";
              }

              (lib.mkIf cfg.collabora.enable {
                # this is needed for setting the correct CSP header
                COLLABORA_DOMAIN = cfg.collabora.collaboraDomain;
                COMPANION_DOMAIN = cfg.collabora.companionDomain;

                # expose nats and the reva gateway for the collaboration service
                GATEWAY_GRPC_ADDR = "0.0.0.0:9142";
                NATS_NATS_HOST = "0.0.0.0";
                NATS_NATS_PORT = "9233";
                NATS_DEBUG_ADDR = "0.0.0.0:9234";

                # make collabora the secure view app
                FRONTEND_APP_HANDLER_SECURE_VIEW_APP_ADDR = "eu.opencloud.api.collaboration.CollaboraOnline";
                # Not sure what this is
                GRAPH_AVAILABLE_ROLES = "b1e2218d-eef8-4d4c-b82d-0f1a1b48f3b5,a8d5fe5e-96e3-418d-825b-534dbdf22b99,fb6c3e19-e378-47e5-b277-9732f9de6e21,58c63c02-1d89-4572-916a-870abc5a1b7d,2d00ce52-1fc2-4dbc-8b95-a73b73395f5a,1c996275-f1c9-4e71-abdf-a42f6495e960,312c0871-5ef7-4b3a-85b6-0e4074c64049,aa97fe03-7980-45ac-9e50-b325749fd7e6";

              })
            ];
          };

          opencloud-tika = {
            autoStart = true;
            image = "apache/tika:3.3.1.0-full@sha256:d8e6ed96260ad89307a93195a1b856102987a818ac648502f8efbaf313d32470";
            extraOptions = [ "--network=opencloud-bridge" ];
          };
        }

        (lib.mkIf cfg.collabora.enable {

          opencloud-collaboration = {
            autoStart = true;
            image = openCloudImage;
            volumes = [
              "/etc/localtime:/etc/localtime:ro"
              "${cfg.configDir}:/etc/opencloud"
            ];
            dependsOn = [
              "opencloud"
              "opencloud-collabora"
            ];
            ports = [ "${toString cfg.collabora.companionPort}:9300" ];
            networks = [ "opencloud-bridge" ];
            entrypoint = "/bin/sh";
            cmd = [
              "-c"
              ''
                set -e

                echo "Waiting for NATS (opencloud:9234) health..."
                timeout 5 sh -c 'until curl -fsS http://opencloud:9234/healthz >/dev/null; do sleep 1; done'

                echo "Waiting for gateway gRPC port (opencloud:9142)..."
                timeout 10 sh -c '
                  # curl exit code 7 = cannot connect (port closed). Any other result means socket accepted.
                  until (curl --max-time 1 http://opencloud:9142 >/dev/null 2>&1 || [ $? -ne 7 ]); do
                    sleep 1
                  done
                '

                sleep 3
                echo "Starting collaboration server..."
                exec opencloud collaboration server
              ''
            ];

            environmentFiles = cfg.environmentFiles;
            environment = {
              PROXY_CSP_CONFIG_FILE_LOCATION = "/etc/opencloud/csp.yaml";
              COLLABORA_DOMAIN = cfg.collabora.collaboraDomain;
              COMPANION_DOMAIN = cfg.collabora.companionDomain;

              COLLABORATION_GRPC_ADDR = "0.0.0.0:9301";
              COLLABORATION_HTTP_ADDR = "0.0.0.0:9300";
              COLLABORATION_WOPI_SRC = "https://${cfg.collabora.companionDomain}";
              COLLABORATION_APP_NAME = "CollaboraOnline";
              COLLABORATION_APP_PRODUCT = "Collabora";
              COLLABORATION_APP_ADDR = "https://${cfg.collabora.collaboraDomain}";
              COLLABORATION_APP_ICON = "https://${cfg.collabora.collaboraDomain}/favicon.ico";
              COLLABORATION_APP_INSECURE = "true";
              COLLABORATION_CS3API_DATAGATEWAY_INSECURE = "true";
              # COLLABORATION_LOG_LEVEL = "info";
              COLLABORATION_STORE = "nats-js-kv";
              COLLABORATION_STORE_NODES = "opencloud:9233";
              MICRO_REGISTRY = "nats-js-kv"; # Seems like we need both
              MICRO_REGISTRY_ADDRESS = "opencloud:9233";
              OC_URL = "https://${cfg.domain}";
            };

          };

          opencloud-collabora = {
            autoStart = true;
            image = "collabora/code:26.04.2.1.1";
            volumes = [
              "/etc/localtime:/etc/localtime:ro"
            ];
            ports = [ "${toString cfg.collabora.collaboraPort}:9980" ];
            networks = [ "opencloud-bridge" ];

            capabilities = {
              CAP_MKNOD = true;
            };
            entrypoint = "/bin/bash";
            cmd = [
              "-c"
              "coolconfig generate-proof-key && /start-collabora-online.sh"
            ];

            environmentFiles = cfg.environmentFiles;
            environment = {
              aliasgroup1 = "https://${cfg.collabora.companionDomain}:443";
              DONT_GEN_SSL_CERT = "YES";
              extra_params = ''
                --o:ssl.enable=false \
                --o:ssl.ssl_verification=true \
                --o:ssl.termination=true \
                --o:welcome.enable=false \
                --o:home_mode.enable=true \
                --o:net.frame_ancestors=${cfg.domain}
              '';
            };
          };

        })
      ];
    };

    # collab flaps on boot until opencloud's nats/gateway is ready; space out its restarts
    systemd.services.podman-opencloud-collaboration = lib.mkIf cfg.collabora.enable {
      serviceConfig = {
        RestartSec = lib.mkForce 5;
      };
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
    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [
        cfg.port
      ]
      ++ lib.optionals cfg.collabora.enable [
        cfg.collabora.collaboraPort
        cfg.collabora.companionPort
      ];
    };

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

    modules.authentik.blueprints.opencloud = lib.mkIf config.modules.authentik.enable ''
      version: 1
      metadata:
        name: opencloud
      entries:
        - id: opencloud-provider
          model: authentik_providers_oauth2.oauth2provider
          identifiers:
            name: opencloud
          attrs:
            name: opencloud
            client_type: public
            client_id: !Env OPENCLOUD_OIDC_CLIENT_ID

            authentication_flow: !Find [authentik_flows.flow, [slug, default-authentication-flow]]
            authorization_flow:  !Find [authentik_flows.flow, [slug, default-provider-authorization-explicit-consent]]
            invalidation_flow:   !Find [authentik_flows.flow, [slug, default-provider-invalidation-flow]]

            access_code_validity:    minutes=1
            access_token_validity:   hours=24
            refresh_token_validity:  days=30
            refresh_token_threshold: seconds=0

            include_claims_in_id_token: true
            issuer_mode: per_provider
            sub_mode: hashed_user_id
            logout_method: backchannel

            signing_key: !Find [authentik_crypto.certificatekeypair, [name, authentik Self-signed Certificate]]

            redirect_uris:
              - matching_mode: strict
                url: "https://${cfg.domain}/"
              - matching_mode: strict
                url: "https://${cfg.domain}/oidc-callback.html"
              - matching_mode: strict
                url: "https://${cfg.domain}/oidc-silent-redirect.html"

            property_mappings:
              - !Find [authentik_providers_oauth2.scopemapping, [scope_name, openid]]
              - !Find [authentik_providers_oauth2.scopemapping, [scope_name, email]]
              - !Find [authentik_providers_oauth2.scopemapping, [scope_name, profile]]
              - !Find [authentik_providers_oauth2.scopemapping, [scope_name, entitlements]]
              - !Find [authentik_providers_oauth2.scopemapping, [scope_name, offline_access]]

        - id: opencloud-desktop-provider
          model: authentik_providers_oauth2.oauth2provider
          identifiers:
            name: opencloud-desktop
          attrs:
            name: opencloud-desktop
            client_type: public
            client_id: !Env OPENCLOUD_DESKTOP_OIDC_CLIENT_ID

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
              - matching_mode: regex
                url: "http://127.0.0.1.*"
              - matching_mode: regex
                url: "http://localhost.*"

            property_mappings:
              - !Find [authentik_providers_oauth2.scopemapping, [scope_name, openid]]
              - !Find [authentik_providers_oauth2.scopemapping, [scope_name, email]]
              - !Find [authentik_providers_oauth2.scopemapping, [scope_name, profile]]
              - !Find [authentik_providers_oauth2.scopemapping, [scope_name, entitlements]]
              - !Find [authentik_providers_oauth2.scopemapping, [scope_name, offline_access]]

        - id: opencloud-android-provider
          model: authentik_providers_oauth2.oauth2provider
          identifiers:
            name: opencloud-android
          attrs:
            name: opencloud-android
            client_type: public
            client_id: !Env OPENCLOUD_ANDROID_OIDC_CLIENT_ID

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
                url: "oc://android.opencloud.eu"

            # Note: android omits the entitlements scope (kept consistent with the export)
            property_mappings:
              - !Find [authentik_providers_oauth2.scopemapping, [scope_name, openid]]
              - !Find [authentik_providers_oauth2.scopemapping, [scope_name, email]]
              - !Find [authentik_providers_oauth2.scopemapping, [scope_name, profile]]
              - !Find [authentik_providers_oauth2.scopemapping, [scope_name, offline_access]]

        - id: opencloud-app
          model: authentik_core.application
          identifiers:
            slug: opencloud
          attrs:
            name: opencloud
            slug: opencloud
            provider: !KeyOf opencloud-provider
            group: cloud
            meta_description: Google drive alternative
            meta_launch_url: https://${cfg.domain}
            meta_icon: https://cdn.jsdelivr.net/gh/selfhst/icons/svg/opencloud.svg
            open_in_new_tab: true
            policy_engine_mode: any

        # Slug fixed from "opecloud-desktop" (typo in original) to "opencloud-desktop"
        - id: opencloud-desktop-app
          model: authentik_core.application
          identifiers:
            slug: opencloud-desktop
          attrs:
            name: opencloud-desktop
            slug: opencloud-desktop
            provider: !KeyOf opencloud-desktop-provider
            group: cloud
            meta_launch_url: blank://blank
            open_in_new_tab: false
            policy_engine_mode: any

        - id: opencloud-android-app
          model: authentik_core.application
          identifiers:
            slug: opencloud-android
          attrs:
            name: opencloud-android
            slug: opencloud-android
            provider: !KeyOf opencloud-android-provider
            group: cloud
            meta_launch_url: blank://blank
            open_in_new_tab: false
            policy_engine_mode: any

        - id: opencloud-cloud-binding
          model: authentik_policies.policybinding
          identifiers:
            target: !KeyOf opencloud-app
            order: 0
          attrs:
            enabled: true
            order: 0
            negate: false
            failure_result: false
            timeout: 30
            group: !Find [authentik_core.group, [name, cloud]]

        - id: opencloud-desktop-cloud-binding
          model: authentik_policies.policybinding
          identifiers:
            target: !KeyOf opencloud-desktop-app
            order: 0
          attrs:
            enabled: true
            order: 0
            negate: false
            failure_result: false
            timeout: 30
            group: !Find [authentik_core.group, [name, cloud]]

        - id: opencloud-android-cloud-binding
          model: authentik_policies.policybinding
          identifiers:
            target: !KeyOf opencloud-android-app
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
