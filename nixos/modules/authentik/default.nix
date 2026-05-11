{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.modules.authentik;

  # Yaml directly to the nix store
  blueprintsDir = pkgs.runCommand "authentik-blueprints" { } (
    lib.concatStringsSep "\n" (
      [ "mkdir -p $out" ]
      ++ lib.mapAttrsToList (
        name: content: "install -m 0644 ${pkgs.writeText "${name}.yaml" content} $out/${name}.yaml"
      ) cfg.blueprints
    )
  );
in
{

  imports = [ ];

  options.modules.authentik = with lib.types; {
    enable = lib.mkEnableOption ''
      Enables the authentik module, uses a nixos container under the hood so the postges db is a seperated service.
       Also uses ephemeral container, so you need to pass the media directory'';

    ldap = lib.mkOption {
      type = types.submodule {
        options = {
          enable = lib.mkEnableOption "Enables the authentik ldap outpost. The envFile needs the required environment variables";

          openFirewall = lib.mkEnableOption "Open the required ports in the firewall for the ldap service";

          ldapPort = lib.mkOption {
            type = types.port;
            default = 389;
            description = "the port for ldap";
          };

          ldapsPort = lib.mkOption {
            type = types.port;
            default = 636;
            description = "the port for ldaps";
          };

          metricsPort = lib.mkOption {
            type = types.port;
            default = 9301;
            description = "the port for http access";
          };
        };
      };
    };

    openFirewall = lib.mkEnableOption "Open the required ports in the firewall";

    envFile = lib.mkOption {
      type = types.str;
      description = "Path to the environment file";
    };

    dataDir = lib.mkOption {
      type = types.str;
      description = "Path to where the data will be stored";
    };

    mediaDir = lib.mkOption {
      type = types.str;
      description = "Path to the media directory";
    };

    backupDir = lib.mkOption {
      type = types.str;
      description = "Path to where the database will be backed up. Yes, you are required to backup your databases. Even if you think you don't, you do.";
    };

    port = lib.mkOption {
      type = types.port;
      default = 9000;
      description = "the port for http access";
    };

    metricsPort = lib.mkOption {
      type = types.port;
      default = 9300;
      description = "the port for http access";
    };

    blueprints = lib.mkOption {
      type = types.attrsOf types.lines;
      default = { };
      description = ''
        Authentik blueprints to install. Each entry becomes a YAML file
        at /blueprints/local/<name>.yaml inside the container, applied on
        startup and re-applied every 60 minutes.

        Other modules contribute by setting
          modules.authentik.blueprints.<their-name> = "..."
      '';
    };
  };

  # We use a contianer so other services can have a different PG version
  config = lib.mkIf cfg.enable {
    containers.authentik = {
      autoStart = true;
      ephemeral = true;
      restartIfChanged = true;
      privateUsers = "identity";

      # Access to the host data
      bindMounts = {

        "${cfg.envFile}" = {
          hostPath = cfg.envFile;
          isReadOnly = true;
        };

        "${cfg.dataDir}" = {
          hostPath = cfg.dataDir;
          isReadOnly = false;
        };
        "${cfg.backupDir}" = {
          hostPath = cfg.backupDir;
          isReadOnly = false;
        };
        "/var/lib/authentik/media" = {
          hostPath = cfg.mediaDir;
          isReadOnly = false;
        };
      };

      config =
        { config, ... }:
        let
          # authentik-nix sets blueprints_dir to ${staticWorkdirDeps}/blueprints
          # (a nix-store path), which means we can't drop additional blueprint
          # files there
          #
          # TODO: remove once https://github.com/nix-community/authentik-nix/issues/98 is fixed
          upstreamBlueprints = "${config.services.authentik.authentikComponents.staticWorkdirDeps}/blueprints";
          mergedBlueprints =
            if cfg.blueprints == { } then
              upstreamBlueprints
            else
              pkgs.runCommand "authentik-blueprints-merged" { } ''
                mkdir -p $out/local
                cp -r ${upstreamBlueprints}/. $out/
                cp ${blueprintsDir}/*.yaml $out/local/
                chmod -R u+w $out
              '';
        in
        {
          nixpkgs.pkgs = pkgs;
          imports = [ inputs.authentik-nix.nixosModules.default ];

          networking.useHostResolvConf = true;
          systemd.services.authentik-ldap.serviceConfig.Environment = [
            "AUTHENTIK_LISTEN__LDAP=0.0.0.0:${toString cfg.ldap.ldapPort}"
            "AUTHENTIK_LISTEN__LDAPS=0.0.0.0:${toString cfg.ldap.ldapsPort}"
            "AUTHENTIK_LISTEN__METRICS=0.0.0.0:${toString cfg.ldap.metricsPort}"
          ];

          services = {
            authentik = {
              enable = true;
              createDatabase = true;
              environmentFile = cfg.envFile;
              settings = {
                disable_startup_analytics = true;
                avatars = "gravatar,initials";
                listen = {
                  http = "0.0.0.0:${toString cfg.port}";
                  metrics = "0.0.0.0:${toString cfg.metricsPort}";
                };
                paths.media = "/var/lib/authentik/media";
                blueprints_dir = lib.mkForce "${mergedBlueprints}";
              };
            };

            authentik-ldap = lib.mkIf cfg.ldap.enable {
              enable = true;
              environmentFile = cfg.envFile;
            };

            # Some override of the internal services
            postgresql.dataDir = "${cfg.dataDir}/postgres";

            postgresqlBackup = {
              enable = true;
              backupAll = true;
              location = cfg.backupDir;
            };
          };

          # Create the sub folder
          systemd.tmpfiles.settings.authentik = {

            "${cfg.dataDir}/postgres" = {
              d = {
                user = "postgres";
                group = "postgres";
                mode = "700";
              };
            };
          };

          system.stateVersion = "23.11";
        };
    };

    networking = {
      firewall = lib.mkIf cfg.openFirewall (
        lib.mkMerge [
          { allowedTCPPorts = [ cfg.port ]; }
          (lib.mkIf (cfg.ldap.enable && cfg.ldap.openFirewall) {
            allowedTCPPorts = [
              cfg.ldap.ldapPort
              cfg.ldap.ldapsPort
            ];
            allowedUDPPorts = [
              cfg.ldap.ldapPort
              cfg.ldap.ldapsPort
            ];
          })
        ]
      );
    };

    modules.authentik.blueprints.groups = ''
      version: 1
      metadata:
        name: groups
      entries:
        - model: authentik_core.group
          identifiers: { name: user }
          attrs: { name: user, is_superuser: false }
        - model: authentik_core.group
          identifiers: { name: media }
          attrs: { name: media, is_superuser: false }
        - model: authentik_core.group
          identifiers: { name: cloud }
          attrs: { name: cloud, is_superuser: false }
        - model: authentik_core.group
          identifiers: { name: ldapsearch }
          attrs: { name: ldapsearch, is_superuser: false }
        - model: authentik_core.group
          identifiers: { name: guest }
          attrs: { name: guest, is_superuser: false }
        - model: authentik_core.group
          identifiers: { name: admin }
          attrs: { name: admin, is_superuser: false }
    '';

    modules.authentik.blueprints.recovery = ''
      version: 1
      metadata:
        name: recovery
      entries:
        - id: recovery-flow
          model: authentik_flows.flow
          identifiers:
            slug: recovery
          attrs:
            name: Recovery
            title: Recovery
            designation: recovery
            authentication: none
            denied_action: message_continue
            policy_engine_mode: any
            layout: stacked

        - id: recovery-identification-stage
          model: authentik_stages_identification.identificationstage
          identifiers:
            name: recovery-authentication-identification
          attrs:
            name: recovery-authentication-identification
            case_insensitive_matching: true
            pretend_user_exists: true
            show_matched_user: true
            user_fields:
              - username
              - email

        - id: recovery-email-stage
          model: authentik_stages_email.emailstage
          identifiers:
            name: email-password-reset
          attrs:
            name: email-password-reset
            activate_user_on_success: true
            subject: authentik
            template: email/password_reset.html
            timeout: 10
            token_expiry: minutes=30
            use_global_settings: true

        - id: recovery-binding-identification
          model: authentik_flows.flowstagebinding
          identifiers:
            target: !Find [authentik_flows.flow, [slug, recovery]]
            order: 0
          attrs:
            target: !Find [authentik_flows.flow, [slug, recovery]]
            stage: !Find [authentik_stages_identification.identificationstage, [name, recovery-authentication-identification]]
            order: 0
            re_evaluate_policies: true

        - id: recovery-binding-email
          model: authentik_flows.flowstagebinding
          identifiers:
            target: !Find [authentik_flows.flow, [slug, recovery]]
            order: 10
          attrs:
            target: !Find [authentik_flows.flow, [slug, recovery]]
            stage: !Find [authentik_stages_email.emailstage, [name, email-password-reset]]
            order: 10
            re_evaluate_policies: true

        - id: recovery-binding-prompt
          model: authentik_flows.flowstagebinding
          identifiers:
            target: !Find [authentik_flows.flow, [slug, recovery]]
            order: 20
          attrs:
            target: !Find [authentik_flows.flow, [slug, recovery]]
            stage: !Find [authentik_stages_prompt.promptstage, [name, default-password-change-prompt]]
            order: 20
            re_evaluate_policies: true

        - id: recovery-binding-write
          model: authentik_flows.flowstagebinding
          identifiers:
            target: !Find [authentik_flows.flow, [slug, recovery]]
            order: 30
          attrs:
            target: !Find [authentik_flows.flow, [slug, recovery]]
            stage: !Find [authentik_stages_user_write.userwritestage, [name, default-password-change-write]]
            order: 30
            re_evaluate_policies: true

        # Wire the recovery flow into the default brand
        - model: authentik_brands.brand
          identifiers:
            domain: authentik-default
          attrs:
            flow_recovery: !Find [authentik_flows.flow, [slug, recovery]]

        # Attach recovery_flow to the default identification stage so the
        # "Forgot password?" link shows during login. user_fields must be
        # included because the serializer enforces "user_fields OR sources
        # must be non-empty" on the full record. sources stays out so Google
        # remains a manual UI step.
        - model: authentik_stages_identification.identificationstage
          identifiers:
            name: default-authentication-identification
          attrs:
            user_fields:
              - email
              - username
            recovery_flow: !Find [authentik_flows.flow, [slug, recovery]]
    '';

    modules.authentik.blueprints.ldap = lib.mkIf cfg.ldap.enable ''
      version: 1
      metadata:
        name: ldap
      entries:
        - id: ldapsearch-group
          model: authentik_core.group
          identifiers:
            name: ldapsearch
          attrs:
            name: ldapsearch
            is_superuser: false

        - id: ldap-search-role
          model: authentik_rbac.role
          identifiers:
            name: LDAP Search

        - id: ldap-provider
          model: authentik_providers_ldap.ldapprovider
          identifiers:
            name: LDAP
          attrs:
            name: LDAP
            base_dn: DC=ldap,DC=xgroleau,DC=com
            bind_mode: cached
            search_mode: cached
            mfa_support: true
            uid_start_number: 2000
            gid_start_number: 4000
            authorization_flow: !Find [authentik_flows.flow, [slug, default-authentication-flow]]
            invalidation_flow:  !Find [authentik_flows.flow, [slug, default-provider-invalidation-flow]]
          permissions:
            - permission: authentik_providers_ldap.search_full_directory
              role: !Find [authentik_rbac.role, [name, LDAP Search]]

        - id: ldap-app
          model: authentik_core.application
          identifiers:
            slug: ldap
          attrs:
            name: LDAP
            slug: ldap
            provider: !KeyOf ldap-provider
            meta_launch_url: blank://blank
            open_in_new_tab: false
            policy_engine_mode: any

        - id: ldapservice-user
          model: authentik_core.user
          identifiers:
            username: ldapservice
          attrs:
            username: ldapservice
            name: ldapservice
            type: internal
            is_active: true
            path: users
            password: !Env LDAPSERVICE_PASSWORD
            groups:
              - !Find [authentik_core.group, [name, ldapsearch]]
            roles:
              - !Find [authentik_rbac.role, [name, LDAP Search]]

        - id: ldap-outpost
          model: authentik_outposts.outpost
          identifiers:
            name: LDAP
          attrs:
            name: LDAP
            type: ldap
            providers:
              - !Find [authentik_providers_ldap.ldapprovider, [name, LDAP]]
            config:
              authentik_host: !Env AUTHENTIK_HOST
              authentik_host_browser: ""
              authentik_host_insecure: false
              log_level: info
              object_naming_template: "ak-outpost-%(name)s"
              container_image: null
              docker_network: null
              docker_map_ports: true
              docker_labels: null
              kubernetes_replicas: 1
              kubernetes_namespace: default
              kubernetes_ingress_class_name: null
              kubernetes_ingress_secret_name: authentik-outpost-tls
              kubernetes_ingress_annotations: {}
              kubernetes_service_type: ClusterIP
              kubernetes_disabled_components: []
              kubernetes_image_pull_secrets: []
              kubernetes_json_patches: null

        # Outpost auto-creates a service account named "Outpost LDAP Service-Account"
        # at outpost creation time. This entry attaches the LDAP Search role to it
        # after the outpost (and thus its service account) exists.
        - id: ldap-outpost-user
          model: authentik_core.user
          identifiers:
            name: Outpost LDAP Service-Account
          attrs:
            roles:
              - !Find [authentik_rbac.role, [name, LDAP Search]]
    '';

    # Allow to write to backupdir
    users.users.postgres = lib.mkDefault {
      isSystemUser = true;
      group = "postgres";
      uid = config.ids.uids.postgres;
    };
    users.groups.postgres = lib.mkDefault {
      gid = config.ids.gids.postgres;
    };

    # Create the folder if it doesn't exist
    systemd.tmpfiles.settings.authentik = {
      "${cfg.dataDir}" = {
        d = {
          user = "root";
          mode = "777";
        };
      };

      "${cfg.mediaDir}" = {
        d = {
          user = "root";
          mode = "777";
        };
      };

      "${cfg.backupDir}" = {
        d = {
          user = "postgres";
          group = "postgres";
          mode = "700";
        };
      };
    };
  };
}
