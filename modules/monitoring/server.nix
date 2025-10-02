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
    services = {

      grafana = {
        enable = true;
        settings = {
          server = rec {
            protocol = "http";
            http_port = cfg.grafanaPort;
            http_addr = "0.0.0.0";
            domain = hostname;
          };
          analytics.reporting_enabled = false;
        };

        provision = {
          enable = true;
          datasources.settings.datasources = [
            {
              name = "Prometheus";
              type = "prometheus";
              access = "proxy";
              url = "http://127.0.0.1:${toString cfg.prometheusPort}";
            }
            {
              name = "Loki";
              type = "loki";
              access = "proxy";
              url = "http://127.0.0.1:${toString cfg.lokiPort}";
            }
          ];
        };
      };

      prometheus = {
        enable = true;
        port = cfg.prometheusPort;

        rules = [
          (builtins.toJSON {
            groups = [
              {
                name = "nixos-monitoring";
                rules = [
                  {
                    alert = "NodeDown";
                    expr = "up == 0";
                    for = "5m";
                    annotations = {
                      summary = "{{$labels.alias}}: Node is down.";
                      description = "{{$labels.alias}} has been down for more than 5 minutes.";
                    };
                  }
                  {
                    alert = "Node90Full";
                    expr = ''sort(node_filesystem_free{device!="ramfs"} < node_filesystem_size{device!="ramfs"} * 0.1) / 1024^3'';
                    for = "5m";
                    annotations = {
                      summary = "{{$labels.alias}}: Filesystem is running out of space soon.";
                      description = "{{$labels.alias}} device {{$labels.device}} on {{$labels.mountpoint}} got less than 10% space left on its filesystem.";
                    };
                  }
                  {
                    alert = "Node90FullIn4H";
                    expr = ''predict_linear(node_filesystem_free{device!="ramfs"}[1h], 4*3600) <= 0'';
                    for = "5m";
                    annotations = {
                      summary = "{{$labels.alias}}: Filesystem is running out of space in 4 hours.";
                      description = "{{$labels.alias}} device {{$labels.device}} on {{$labels.mountpoint}} is running out of space of in approx. 4 hours";
                    };
                  }
                  {
                    alert = "NodeFiledescriptorsFull3h";
                    expr = "predict_linear(node_filefd_allocated[1h], 3*3600) >= node_filefd_maximum";
                    for = "10m";
                    annotations = {
                      summary = "{{$labels.alias}} is running out of available file descriptors in 3 hours.";
                      description = "{{$labels.alias}} is running out of available file descriptors in approx. 3 hours";
                    };
                  }
                  {
                    alert = "NodeLoad1At90percent";
                    expr = ''node_load1 / on(alias) count(node_cpu{mode="system"}) by (alias) >= 0.9'';
                    for = "1h";
                    annotations = {
                      summary = "{{$labels.alias}}: Running on high load.";
                      description = "{{$labels.alias}} is running with > 90% total load for at least 1h.";
                    };
                  }
                  {
                    alert = "NodeCpuUtil90Percent";
                    expr = ''100 - (avg by (alias) (irate(node_cpu{mode="idle"}[5m])) * 100) >= 90'';
                    for = "1h";
                    annotations = {
                      summary = "{{$labels.alias}}: High CPU utilization.";
                      description = "{{$labels.alias}} has total CPU utilization over 90% for at least 1h.";
                    };
                  }
                  {
                    alert = "NodeRamUsing90Percent";
                    expr = ''
                      node_memory_MemFree + node_memory_Buffers + node_memory_Cached < node_memory_MemTotal * 0.1
                    '';
                    for = "130m";
                    annotations = {
                      summary = "{{$labels.alias}}: Using lots of RAM.";
                      description = "{{$labels.alias}} is using at least 90% of its RAM for at least 130 minutes now.";
                    };
                  }
                  {
                    alert = "NodeSwapUsing80Percent";
                    expr = ''
                      node_memory_SwapTotal - (node_memory_SwapFree + node_memory_SwapCached) > node_memory_SwapTotal * 0.8
                    '';
                    for = "10m";
                    annotations = {
                      summary = "{{$labels.alias}}: Running out of swap soon.";
                      description = "{{$labels.alias}} is using 80% of its swap space for at least 10 minutes now.";
                    };
                  }

                  {
                    alert = "SystemDUnitDown";
                    expr = ''node_systemd_unit_state{state="failed"} == 1'';
                    for = "5m";
                    annotations = {
                      summary = "{{$labels.instance}} failed to (re)start the following service {{$labels.name}}.";
                    };
                  }
                  {
                    alert = "RootPartitionFull";
                    for = "10m";
                    expr = ''(node_filesystem_free_bytes{mountpoint="/"} * 100) / node_filesystem_size_bytes{mountpoint="/"} < 10'';
                    annotations = {
                      summary = ''{{ $labels.job }} running out of space: {{ $value | printf "%.2f" }}% < 10%'';
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
                "alias"
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
            path_prefix = "/tmp/loki";
            storage = {
              filesystem = {
                chunks_directory = "/tmp/loki/chunks";
                rules_directory = "/tmp/loki/rules";
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
  };
}
