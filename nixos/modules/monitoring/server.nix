{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.monitoring.server;
  hostname = config.networking.hostName;
in
{

  options.modules.monitoring.server = with lib.types; {
    enable = lib.mkEnableOption "Monitoring module, will monitor another server, see config.modules.monitoring.target for the target system to monitor";

    prometheusScrapeUrls = lib.mkOption {
      type = types.listOf types.str;
      description = "Prometheus nodes to scrape";
    };

    grafanaPort = lib.mkOption {
      type = types.port;
      default = 13010;
      description = "Port for the grafana UI";
    };

    grafanaAdminPasswordFile = lib.mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Path to a file containing the Grafana admin password, read via Grafana's
        file provider. Only applied when the grafana DB is first created.
      '';
    };

    grafanaSecretKeyFile = lib.mkOption {
      type = types.nullOr types.str;
      description = ''
        Path to a file containing Grafana's secret_key (used to encrypt secrets
        stored in the database), read via Grafana's file provider.
      '';
    };

    prometheusPort = lib.mkOption {
      type = types.port;
      default = 13020;
      description = "Port for the prometheus server UI";
    };

    lokiPort = lib.mkOption {
      type = types.port;
      default = 13100;
      description = "Port for the loki server";
    };

    alerting = lib.mkOption {
      type = types.submodule {
        options = {
          enable = lib.mkEnableOption "Monitoring module";

          port = lib.mkOption {
            type = types.port;
            default = 13024;
            description = "Port for the alert manager ui";
          };
          envFile = lib.mkOption {
            type = types.str;
            description = ''
              Path to the environment file for sending email notifications, must contain
              SMTP_HOST,
              SMTP_PORT,
              SMTP_SENDER,
              SMTP_USERNAME,
              SMTP_PASSWORD,
            '';
          };
          emailTo = lib.mkOption {
            type = types.str;
            description = "Addresse email to send the notifications to";
          };
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    users.deterministicIds = {
      grafana = {
        uid = 991;
        gid = 991;
      };
      loki = {
        uid = 990;
        gid = 990;
      };
    };

    services = {

      grafana =
        let
          dashboard =
            id: rev: hash:
            pkgs.fetchurl {
              url = "https://grafana.com/api/dashboards/${toString id}/revisions/${toString rev}/download";
              inherit hash;
            };

          # 13639 ships ${DS_LOKI} import-input placeholders.
          logsApp = pkgs.runCommand "logs-app.json" { } ''
            sed 's|"''${DS_LOKI}"|{"type": "loki", "uid": "loki"}|g' ${
              dashboard 13639 2 "sha256-2dRUkooIA1E0Qshg58N+9duIW25iRruu1oW8ckBUNIA="
            } > $out
          '';
          dashboards = pkgs.linkFarm "grafana-dashboards" [
            {
              name = "node-exporter-full.json";
              path = dashboard 1860 45 "sha256-GExrdAnzBtp1Ul13cvcZRbEM6iOtFrXXjEaY6g6lGYY=";
            }
            {
              name = "alertmanager.json";
              path = dashboard 9578 4 "sha256-/scCKBKqTjRKKImIrEYLBKGweOUnkx+QsD5yLfdXW5o=";
            }
            {
              name = "logs-app.json";
              path = logsApp;
            }
          ];
        in
        {
          enable = true;
          settings = {
            server = rec {
              protocol = "http";
              http_port = cfg.grafanaPort;
              http_addr = "0.0.0.0";
              domain = hostname;
            };
            analytics.reporting_enabled = false;
            security.admin_password = lib.mkIf (
              cfg.grafanaAdminPasswordFile != null
            ) "$__file{${cfg.grafanaAdminPasswordFile}}";
            security.secret_key = "$__file{${cfg.grafanaSecretKeyFile}}";
          };

          provision = {
            enable = true;
            datasources.settings.datasources = [
              {
                name = "Prometheus";
                uid = "prometheus";
                isDefault = true;
                type = "prometheus";
                access = "proxy";
                url = "http://127.0.0.1:${toString cfg.prometheusPort}";
              }
              {
                name = "Loki";
                uid = "loki";
                type = "loki";
                access = "proxy";
                url = "http://127.0.0.1:${toString cfg.lokiPort}";
              }
            ];
            dashboards.settings.providers = [
              { options.path = dashboards; }
            ];
          };
        };

      prometheus = {
        enable = true;
        port = cfg.prometheusPort;
        retentionTime = "90d";

        rules = [
          (builtins.toJSON {
            groups = [
              {
                name = "nixos-monitoring";
                rules = [
                  {
                    record = "node_systemd_unit_state";
                    expr = "nixos_container_systemd_unit_state";
                  }
                  {
                    alert = "NodeDown";
                    expr = "up == 0";
                    for = "5m";
                    annotations = {
                      summary = "{{$labels.instance}}: Node is down.";
                      description = "{{$labels.instance}} has been down for more than 5 minutes.";
                    };
                  }
                  {
                    alert = "Node90Full";
                    expr = ''(node_filesystem_avail_bytes{fstype!~"tmpfs|ramfs"} / node_filesystem_size_bytes{fstype!~"tmpfs|ramfs"}) < 0.10'';
                    for = "5m";
                    annotations = {
                      summary = "{{$labels.instance}}: Filesystem is running out of space soon.";
                      description = "{{$labels.instance}} device {{$labels.device}} on {{$labels.mountpoint}} got less than 10% space left on its filesystem.";
                    };
                  }
                  {
                    alert = "Node90FullIn4H";
                    expr = ''predict_linear(node_filesystem_avail_bytes{fstype!~"tmpfs|ramfs"}[1h], 4*3600) <= 0'';
                    for = "5m";
                    annotations = {
                      summary = "{{$labels.instance}}: Filesystem is running out of space in 4 hours.";
                      description = "{{$labels.instance}} device {{$labels.device}} on {{$labels.mountpoint}} is running out of space of in approx. 4 hours";
                    };
                  }
                  {
                    alert = "NodeFiledescriptorsFull3h";
                    expr = "predict_linear(node_filefd_allocated[1h], 3*3600) >= node_filefd_maximum";
                    for = "10m";
                    annotations = {
                      summary = "{{$labels.instance}} is running out of available file descriptors in 3 hours.";
                      description = "{{$labels.instance}} is running out of available file descriptors in approx. 3 hours";
                    };
                  }
                  {
                    alert = "NodeLoad1At90percent";
                    expr = ''node_load1 / on(instance) count(node_cpu_seconds_total{mode="system"}) by (instance) >= 0.9'';
                    for = "1h";
                    annotations = {
                      summary = "{{$labels.instance}}: Running on high load.";
                      description = "{{$labels.instance}} is running with > 90% total load for at least 1h.";
                    };
                  }
                  {
                    alert = "NodeCpuUtil90Percent";
                    expr = ''100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) >= 90'';
                    for = "1h";
                    annotations = {
                      summary = "{{$labels.instance}}: High CPU utilization.";
                      description = "{{$labels.instance}} has total CPU utilization over 90% for at least 1h.";
                    };
                  }
                  {
                    alert = "NodeRamUsing90Percent";
                    expr = "node_memory_MemAvailable_bytes < node_memory_MemTotal_bytes * 0.1";
                    for = "130m";
                    annotations = {
                      summary = "{{$labels.instance}}: Using lots of RAM.";
                      description = "{{$labels.instance}} is using at least 90% of its RAM for at least 130 minutes now.";
                    };
                  }
                  {
                    alert = "NodeOutOfMemorySoon";
                    expr = ''
                      node_memory_SwapFree_bytes < node_memory_SwapTotal_bytes * 0.1
                      and
                      node_memory_MemAvailable_bytes < node_memory_MemTotal_bytes * 0.2
                    '';
                    for = "10m";
                    annotations = {
                      summary = "{{$labels.instance}}: Low on memory and swap.";
                      description = "{{$labels.instance}} has under 10% swap free and under 20% RAM available for 10 minutes: real memory pressure, OOM risk.";
                    };
                  }
                  {
                    alert = "NodeExporterMetricsMissing";
                    expr = "absent(node_memory_MemAvailable_bytes) or absent(node_filesystem_avail_bytes) or absent(node_cpu_seconds_total)";
                    for = "15m";
                    annotations = {
                      summary = "Core node_exporter metrics are absent from prometheus.";
                      description = "A metric referenced by the alert rules no longer exists, rules relying on it can never fire. Check for node_exporter metric renames.";
                    };
                  }

                  {
                    alert = "SystemDUnitDown";
                    expr = ''node_systemd_unit_state{state="failed"} == 1'';
                    for = "10m";
                    annotations = {
                      summary = "{{$labels.instance}}{{if $labels.container}} container {{$labels.container}}{{end}} failed to (re)start service {{$labels.name}}.";
                    };
                  }
                  {
                    alert = "NixosContainerSystemDMetricsStale";
                    expr = "time() - nixos_container_systemd_scrape_timestamp_seconds > 300";
                    for = "5m";
                    annotations = {
                      summary = "{{$labels.instance}} has stale container systemd metrics.";
                      description = "The monitoring target has not published fresh container systemd metrics for more than 5 minutes.";
                    };
                  }
                  {
                    alert = "NixosContainerDown";
                    expr = "nixos_container_systemd_up == 0";
                    for = "5m";
                    annotations = {
                      summary = "{{$labels.instance}} cannot query systemd in container {{$labels.container}}.";
                      description = "The monitoring target cannot query systemd units inside container {{$labels.container}} for more than 5 minutes.";
                    };
                  }
                ];
              }
            ];
          })
        ];

        scrapeConfigs = [
          {
            job_name = "nodes";
            static_configs = [ { targets = cfg.prometheusScrapeUrls; } ];
          }
          {
            job_name = "loki";
            static_configs = [ { targets = [ "127.0.0.1:${toString cfg.lokiPort}" ]; } ];
          }
        ]
        ++ lib.optionals cfg.alerting.enable [
          {
            job_name = "alertmanager";
            static_configs = [ { targets = [ "127.0.0.1:${toString cfg.alerting.port}" ]; } ];
          }
        ];

        # Send notifications to
        alertmanagers =
          if cfg.alerting.enable then
            [
              {
                scheme = "http";
                path_prefix = "/";
                static_configs = [ { targets = [ "127.0.0.1:${toString cfg.alerting.port}" ]; } ];
              }
            ]
          else
            [ ];

        #Receive notifications
        alertmanager = lib.mkIf cfg.alerting.enable {
          enable = true;
          port = cfg.alerting.port;
          environmentFile = cfg.alerting.envFile;
          listenAddress = "0.0.0.0";
          configuration = {
            global = {
              smtp_require_tls = true;
              smtp_smarthost = "$SMTP_HOST:$SMTP_PORT";
              smtp_from = "$SMTP_SENDER";
              smtp_auth_username = "$SMTP_USERNAME";
              smtp_auth_password = "$SMTP_PASSWORD";
            };
            route = {
              group_by = [
                "alertname"
                "instance"
              ];
              group_wait = "10s";
              receiver = "admin-smtp";
            };
            receivers = [
              {
                name = "admin-smtp";
                email_configs = [
                  {
                    to = cfg.alerting.emailTo;
                    send_resolved = false;
                  }
                ];
              }
            ];
          };
        };
      };

      loki = {
        enable = true;
        configuration = {
          auth_enabled = false;
          server = {
            http_listen_port = cfg.lokiPort;
          };

          common = {
            instance_addr = "0.0.0.0";
            path_prefix = "/var/lib/loki";
            storage = {
              filesystem = {
                chunks_directory = "/var/lib/loki/chunks";
                rules_directory = "/var/lib/loki/rules";
              };
            };
            replication_factor = 1;
            ring = {
              kvstore.store = "inmemory";
            };
          };

          query_range = {
            results_cache = {
              cache = {
                embedded_cache = {
                  enabled = true;
                  max_size_mb = 100;
                };
              };
            };
          };

          schema_config = {
            configs = [
              {
                from = "2020-10-24";
                store = "tsdb";
                object_store = "filesystem";
                schema = "v13";
                index = {
                  prefix = "index_";
                  period = "24h";
                };
              }
            ];
          };

          limits_config = {
            reject_old_samples = true;
            reject_old_samples_max_age = "168h";
            # Without this the compactor deletes nothing (default 0s = keep forever)
            # and /var/lib/loki grows unbounded. Must be a multiple of the 24h index period.
            retention_period = "2160h";
          };

          compactor = {
            retention_enabled = true;
            working_directory = "/var/lib/loki";
            delete_request_store = "filesystem";
            compactor_ring.kvstore.store = "inmemory";
          };

          analytics = {
            reporting_enabled = false;
          };
        };
      };
    };

    preservation.preserveAt."/persist".directories = [
      {
        directory = "/var/lib/grafana";
        user = "grafana";
        group = "grafana";
        mode = "0750";
      }
      {
        directory = "/var/lib/${config.services.prometheus.stateDir}";
        user = "prometheus";
        group = "prometheus";
        mode = "0700";
      }
      {
        directory = "/var/lib/loki";
        user = "loki";
        group = "loki";
        mode = "0750";
      }
    ]
    ++ lib.optionals cfg.alerting.enable [
      {
        directory = "/var/lib/private/alertmanager";
        user = "root";
        group = "root";
        mode = "0700";
      }
    ];
  };
}
