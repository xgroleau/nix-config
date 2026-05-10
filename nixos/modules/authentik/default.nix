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

    modules.authentik.blueprints.ldap = lib.mkIf cfg.ldap.enable ''
      version: 1
      metadata:
        name: ldap
      entries:
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

        - id: ldap-search-binding
          model: authentik_policies.policybinding
          identifiers:
            target: !KeyOf ldap-app
            order: 0
          attrs:
            enabled: true
            order: 0
            negate: false
            failure_result: false
            timeout: 30
            group: !Find [authentik_core.group, [name, ldapsearch]]

        - id: ldapservice-user
          model: authentik_core.user
          identifiers:
            username: ldapservice
          attrs:
            username: ldapservice
            name: LDAP Service Account
            type: service_account
            is_active: true
            path: users
            groups:
              - !Find [authentik_core.group, [name, ldapsearch]]

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
              authentik_host_insecure: !Env [AUTHENTIK_INSECURE, false]
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
