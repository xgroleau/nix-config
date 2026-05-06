{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.security;
  caddyEnabled = config.services.caddy.enable;
in
{
  options.modules.security = {
    enable = lib.mkEnableOption "server security hardening";

    trustedCidrs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "10.0.0.0/8"
        "172.16.0.0/12"
        "192.168.0.0/16"
        "100.64.0.0/10"
        "fc00::/7"
        "fe80::/10"
      ];
      description = "CIDR ranges that should not be banned by fail2ban or CrowdSec.";
    };

    crowdsec.enable = lib.mkEnableOption "CrowdSec threat detection and remediation";

    fail2ban.enable = lib.mkEnableOption "fail2ban SSH protection";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        services.openssh.settings = lib.mkIf config.services.openssh.enable {
          LoginGraceTime = lib.mkDefault "30s";
          MaxAuthTries = lib.mkDefault 3;
          PermitRootLogin = lib.mkDefault "prohibit-password";
        };
      }

      (lib.mkIf cfg.crowdsec.enable {
        services.crowdsec = {
          enable = true;
          # TODO: Remove once we have v1.7.7
          package = pkgs.unstable.crowdsec;
          # TODO: re-enable once https://github.com/NixOS/nixpkgs/pull/446307 lands
          autoUpdateService = false;
          openFirewall = false;

          hub.collections = [
            "crowdsecurity/linux"
            "crowdsecurity/sshd"
          ]
          ++ lib.optionals caddyEnabled [
            "crowdsecurity/caddy"
          ];

          settings = {
            # TODO: drop once https://github.com/NixOS/nixpkgs/pull/446307 lands —
            # module currently fails to evaluate when this is null (the default).
            lapi.credentialsFile = "/var/lib/crowdsec/state/local_api_credentials.yaml";
            general.api.server.enable = true;
          };

          localConfig = {
            acquisitions = [
              {
                source = "journalctl";
                journalctl_filter = [
                  "_SYSTEMD_UNIT=sshd.service"
                ];
                labels.type = "syslog";
              }
            ]
            ++ lib.optionals caddyEnabled [
              {
                source = "file";
                filenames = [ "${config.services.caddy.logDir}/access-*.log" ];
                force_inotify = true;
                labels.type = "caddy";
              }
            ];

            postOverflows.s01Whitelist = [
              {
                name = "local/trusted-networks";
                description = "Do not ban local, private, or tailnet addresses.";
                whitelist = {
                  reason = "trusted local networks";
                  cidr = cfg.trustedCidrs;
                };
              }
            ];
          };
        };

        services.crowdsec-firewall-bouncer = {
          enable = true;
          settings = {
            update_frequency = "10s";
            log_level = "info";
          };
        };

        users.users.crowdsec.extraGroups = lib.mkIf caddyEnabled [ "caddy" ];
      })

      (lib.mkIf cfg.fail2ban.enable {
        services.fail2ban = {
          enable = true;
          bantime = "1h";
          maxretry = 5;
          ignoreIP = cfg.trustedCidrs;

          bantime-increment = {
            enable = true;
            maxtime = "1w";
            rndtime = "10m";
          };

          daemonSettings.Definition.logtarget = "/var/log/fail2ban/fail2ban.log";

          jails = {
            sshd.settings = {
              mode = "aggressive";
              findtime = "10m";
              bantime = "1h";
              maxretry = 3;
            };

            recidive.settings = {
              enabled = true;
              filter = "recidive";
              logpath = "/var/log/fail2ban/fail2ban.log";
              findtime = "1d";
              bantime = "1w";
              maxretry = 5;
              banaction = "%(banaction_allports)s";
            };
          };
        };
      })
    ]
  );
}
