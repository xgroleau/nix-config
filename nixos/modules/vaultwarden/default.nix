{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.vaultwarden;
in

{
  options.modules.vaultwarden = with lib.types; {
    enable = lib.mkEnableOption "Vaultwarden, a bitwarden compatible backend";

    port = lib.mkOption {
      type = types.port;
      default = 10400;
      description = "The port to use";
    };

    domain = lib.mkOption {
      type = types.str;
      description = "Domain of the vaultwarden instance.";
    };

    # TODO: Add datadir once we this is completed
    # https://github.com/NixOS/nixpkgs/issues/289473
    # dataDir = lib.mkOption {
    #   type = types.str;
    #   description = "Path to where the data will be backedup";
    # };

    backupDir = lib.mkOption {
      type = types.str;
      description = "Path to where the data will be backedup";
    };

    envFile = lib.mkOption {
      type = types.str;
      description = ''
        Path to where the secrets environment file 
      '';
    };

  };

  config = lib.mkIf cfg.enable {
    users.deterministicIds.vaultwarden = {
      uid = 970;
      gid = 970;
    };

    services.vaultwarden = {
      enable = true;
      domain = cfg.domain;
      package = pkgs.unstable.vaultwarden;
      webVaultPackage = pkgs.unstable.vaultwarden.webvault;
      environmentFile = cfg.envFile;
      dbBackend = "sqlite";
      backupDir = cfg.backupDir;
      config = {
        SIGNUPS_ALLOWED = false;
        ROCKET_ADDRESS = "0.0.0.0";
        ROCKET_PORT = cfg.port;
        ROCKET_LOG = "critical";
      };
    };

    systemd.tmpfiles.settings.vaultwarden = {
      "${cfg.backupDir}" = {
        d = {
          mode = "0700";
          user = config.users.users.vaultwarden.name;
          group = config.users.groups.vaultwarden.name;
        };
      };
    };

    modules.authentik.blueprints.vaultwarden = lib.mkIf config.modules.authentik.enable ''
      version: 1
      metadata:
        name: vaultwarden
      entries:
        # Custom scope mapping — overrides the default `email` scope to add
        # `email_verified: true` claim, which vaultwarden requires.
        - id: vaultwarden-email-verified-scope
          model: authentik_providers_oauth2.scopemapping
          identifiers:
            name: Email verified scope
          attrs:
            name: Email verified scope
            scope_name: email
            description: Email as verfied for vaultwarden
            expression: |
              return {
                  "email": request.user.email,
                  "email_verified": True
              }

        - id: vaultwarden-provider
          model: authentik_providers_oauth2.oauth2provider
          identifiers:
            name: Vaultwarden
          attrs:
            name: Vaultwarden
            client_type: confidential
            client_id: !Env VAULTWARDEN_OIDC_CLIENT_ID
            client_secret: !Env VAULTWARDEN_OIDC_CLIENT_SECRET

            authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-explicit-consent]]
            invalidation_flow:  !Find [authentik_flows.flow, [slug, default-provider-invalidation-flow]]

            access_code_validity:    minutes=1
            access_token_validity:   minutes=8
            refresh_token_validity:  days=30
            refresh_token_threshold: hours=1

            include_claims_in_id_token: true
            issuer_mode: per_provider
            sub_mode: hashed_user_id
            logout_method: backchannel

            signing_key: !Find [authentik_crypto.certificatekeypair, [name, authentik Self-signed Certificate]]

            redirect_uris:
              - matching_mode: strict
                url: "https://${cfg.domain}/identity/connect/oidc-signin"

            property_mappings:
              - !KeyOf vaultwarden-email-verified-scope
              - !Find [authentik_providers_oauth2.scopemapping, [scope_name, openid]]
              - !Find [authentik_providers_oauth2.scopemapping, [scope_name, profile]]
              - !Find [authentik_providers_oauth2.scopemapping, [scope_name, offline_access]]

        - id: vaultwarden-app
          model: authentik_core.application
          identifiers:
            slug: vaultwarden
          attrs:
            name: Vaultwarden
            slug: vaultwarden
            provider: !KeyOf vaultwarden-provider
            group: cloud
            meta_description: A lightweight bitwarden compatible setup
            meta_launch_url: https://${cfg.domain}
            meta_icon: https://cdn.jsdelivr.net/gh/selfhst/icons/svg/vaultwarden.svg
            open_in_new_tab: true
            policy_engine_mode: any

        # Gate access to the app on membership in the `cloud` group
        - id: vaultwarden-cloud-binding
          model: authentik_policies.policybinding
          identifiers:
            target: !KeyOf vaultwarden-app
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
