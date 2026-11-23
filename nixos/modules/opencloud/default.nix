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
  openCloudImage = "opencloudeu/opencloud:9.1.1@sha256:d7d5b547f9e41db24f030d6a6857c4184752b2c875c936952ee0601b6531cd51";

  # TLS client cert/key + WOPI proof key.
  collaboraKeys = pkgs.runCommand "collabora-keys" { nativeBuildInputs = [ pkgs.openssl ]; } ''
    mkdir -p "$out"
    openssl req -x509 -newkey rsa:2048 -nodes -keyout "$out/key.pem" -out "$out/cert.pem" \
      -days 36500 -subj "/CN=collabora-client"
    # -traditional = PKCS#1 ("BEGIN RSA PRIVATE KEY"); coolwsd loads this via Poco, which
    # rejects the PKCS#8 that openssl 3's genrsa now defaults to. Matches coolconfig generate-proof-key.
    openssl genrsa -traditional -out "$out/proof_key" 2048
  '';
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
            default = 9980;
            description = "The port to use for collabora";
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
            dependsOn = [ "opencloud-tika" ];
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
                OC_ADD_RUN_SERVICES = lib.concatStringsSep "," (
                  [ "notifications" ] ++ lib.optional cfg.collabora.enable "collaboration"
                );

                OC_INSECURE = "false";
                OC_URL = "https://${cfg.domain}";
                # OC_LOG_LEVEL = "info";

                PROXY_CSP_CONFIG_FILE_LOCATION = "/etc/opencloud/csp.yaml";
                STORAGE_USERS_POSIX_WATCH_FS = "true";

                #Tika
                SEARCH_EXTRACTOR_TYPE = "tika";
                SEARCH_EXTRACTOR_TIKA_TIKA_URL = "http://opencloud-tika:9998";
                FRONTEND_FULL_TEXT_SEARCH_ENABLED = "true";

                # Overall config
                OC_SHARING_PUBLIC_SHARE_MUST_HAVE_PASSWORD = "false";
                OC_SHARING_PUBLIC_WRITEABLE_SHARE_MUST_HAVE_PASSWORD = "true";
                OC_SPACES_DEFAULT_QUOTA = toString (50 * 1000 * 1000 * 1000);
              }

              # 9.x runs the WOPI server in-process; the proxy serves it under /wopi on the main domain
              (lib.mkIf cfg.collabora.enable {
                # this is needed for setting the correct CSP header
                COLLABORA_DOMAIN = cfg.collabora.collaboraDomain;

                FRONTEND_APP_HANDLER_SECURE_VIEW_APP_ADDR = "eu.opencloud.api.collaboration";
                # Not sure what this is
                GRAPH_AVAILABLE_ROLES = "b1e2218d-eef8-4d4c-b82d-0f1a1b48f3b5,a8d5fe5e-96e3-418d-825b-534dbdf22b99,fb6c3e19-e378-47e5-b277-9732f9de6e21,58c63c02-1d89-4572-916a-870abc5a1b7d,2d00ce52-1fc2-4dbc-8b95-a73b73395f5a,1c996275-f1c9-4e71-abdf-a42f6495e960,312c0871-5ef7-4b3a-85b6-0e4074c64049,aa97fe03-7980-45ac-9e50-b325749fd7e6";

                COLLABORATION_WOPI_SRC = "https://${cfg.domain}";
                COLLABORATION_APP_NAME = "CollaboraOnline";
                COLLABORATION_APP_PRODUCT = "Collabora";
                COLLABORATION_APP_ADDR = "https://${cfg.collabora.collaboraDomain}";
                COLLABORATION_APP_ICON = "https://${cfg.collabora.collaboraDomain}/favicon.ico";
                COLLABORATION_APP_INSECURE = "true";
                COLLABORATION_CS3API_DATAGATEWAY_INSECURE = "true";
              })
            ];
          };

          opencloud-tika = {
            autoStart = true;
            image = "apache/tika:3.3.3.1-full@sha256:36f6f322d5ecf2d0ac12fbdda0fe904625aff73b3363328b35d21bdf9b4c650c";
            extraOptions = [ "--network=opencloud-bridge" ];
          };
        }

        (lib.mkIf cfg.collabora.enable {

          opencloud-collabora = {
            autoStart = true;
            image = "collabora/code:26.04.6.2.1@sha256:a2f5d4e88addd46033d8440f7a13b82f7e6fe444bf8c6b5a3eadc789f0b5342b";
            volumes = [
              "/etc/localtime:/etc/localtime:ro"
              # TLS cert/key/CA + WOPI proof key image ships none; coolwsd loads them from /etc/coolwsd
              "${config.security.pki.caBundle}:/etc/coolwsd/ca-chain.cert.pem:ro"
              "${collaboraKeys}/cert.pem:/etc/coolwsd/cert.pem:ro"
              "${collaboraKeys}/key.pem:/etc/coolwsd/key.pem:ro"
              "${collaboraKeys}/proof_key:/etc/coolwsd/proof_key:ro"

            ];
            ports = [ "${toString cfg.collabora.collaboraPort}:9980" ];
            networks = [ "opencloud-bridge" ];

            capabilities = {
              CAP_MKNOD = true;
            };
            extraOptions = [ "--no-healthcheck" ];

            environmentFiles = cfg.environmentFiles;
            environment = {
              aliasgroup1 = "https://${cfg.domain}:443";
              DONT_GEN_SSL_CERT = "YES";
              SSL_CERT_FILE = "/etc/coolwsd/ca-chain.cert.pem";
              extra_params = "--o:ssl.enable=false --o:ssl.ssl_verification=false --o:ssl.termination=true --o:welcome.enable=false --o:home_mode.enable=true --o:net.frame_ancestors=${cfg.domain} --o:net.lok_allow.host[14]=${cfg.domain}";
            };
          };

        })
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
    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [
        cfg.port
      ]
      ++ lib.optional cfg.collabora.enable cfg.collabora.collaboraPort;
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
            access_token_validity:   hours=1
            refresh_token_validity:  days=180
            refresh_token_threshold: days=173

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
            access_token_validity:   hours=1
            refresh_token_validity:  days=180
            refresh_token_threshold: days=173

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
