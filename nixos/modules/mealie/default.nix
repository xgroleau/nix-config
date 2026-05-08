{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.mealie;
in

{
  options.modules.mealie = with lib.types; {
    enable = lib.mkEnableOption "Mealie, a meal planner and grocery shopping list manager";

    port = lib.mkOption {
      type = types.port;
      default = 10400;
      description = "The port to use";
    };

    url = lib.mkOption {
      type = types.str;
      description = "Public URL of mealie (used for OIDC redirect URIs and launcher).";
    };

    dataDir = lib.mkOption {
      type = types.str;
      description = "Path to where the data will be stored";
    };

    settings = lib.mkOption {
      type = with lib.types; attrsOf anything;
      default = { };
      description = ''
        Configuration of the Mealie service.

        See [the mealie documentation](https://nightly.mealie.io/documentation/getting-started/installation/backend-config/) for available options and default values.

        In addition to the official documentation, you can set {env}`MEALIE_LOG_FILE`.
      '';
      example = {
        ALLOW_SIGNUP = "false";
      };
    };

    credentialsFile = lib.mkOption {
      type = with lib.types; nullOr path;
      default = null;
      example = "/run/secrets/mealie-credentials.env";
      description = ''
        File containing credentials used in mealie such as {env}`POSTGRES_PASSWORD`
        or sensitive LDAP options.

        Expects the format of an `EnvironmentFile=`, as described by {manpage}`systemd.exec(5)`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.mealie = {
      enable = true;
      port = cfg.port;
      credentialsFile = cfg.credentialsFile;
      settings = {
        DATA_DIR = cfg.dataDir;
        ALLOW_SIGNUP = "false";
        MAX_WORKERS = "1";
        WEB_CONCURRENCY = "1";
      }
      // cfg.settings;

    };

    # TODO: Until https://github.com/NixOS/nixpkgs/pull/309969 is merged
    systemd.services.mealie = {
      serviceConfig = {
        ReadWritePaths = [ cfg.dataDir ];
        StateDirectory = lib.mkForce null;
      };

    };

    systemd.tmpfiles.settings.mealie = {
      "${cfg.dataDir}" = {
        d = {
          mode = "0755";
          user = "mealie";
        };
      };
    };

    modules.authentik.blueprints.mealie = lib.mkIf config.modules.authentik.enable ''
      version: 1
      entries:
        - id: mealie-provider
          model: authentik_providers_oauth2.oauth2provider
          identifiers:
            name: Mealie
          attrs:
            name: Mealie
            client_type: confidential
            client_id: !Env MEALIE_OIDC_CLIENT_ID
            client_secret: !Env MEALIE_OIDC_CLIENT_SECRET

            authentication_flow: !Find [authentik_flows.flow, [slug, default-authentication-flow]]
            authorization_flow:  !Find [authentik_flows.flow, [slug, default-provider-authorization-explicit-consent]]
            invalidation_flow:   !Find [authentik_flows.flow, [slug, default-provider-invalidation-flow]]

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
                url: "${cfg.url}"
              - matching_mode: strict
                url: "${cfg.url}/login"

            property_mappings:
              - !Find [authentik_providers_oauth2.scopemapping, [scope_name, openid]]
              - !Find [authentik_providers_oauth2.scopemapping, [scope_name, email]]
              - !Find [authentik_providers_oauth2.scopemapping, [scope_name, profile]]
              - !Find [authentik_providers_oauth2.scopemapping, [scope_name, offline_access]]

        - id: mealie-app
          model: authentik_core.application
          identifiers:
            slug: mealie
          attrs:
            name: Mealie
            slug: mealie
            provider: !KeyOf mealie-provider
            group: cloud
            meta_description: Manage food recipes and grocery shopping list
            meta_launch_url: ${cfg.url}
            meta_icon: ${cfg.url}/favicon.ico
            open_in_new_tab: true
            policy_engine_mode: any

        # Gate access to the app on membership in the `cloud` group
        - id: mealie-cloud-binding
          model: authentik_policies.policybinding
          identifiers:
            target: !KeyOf mealie-app
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
