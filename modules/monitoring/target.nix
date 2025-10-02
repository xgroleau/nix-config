{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.monitoring.target;
  hostname = config.networking.hostName;
in
{

  options.modules.monitoring.target = with lib.types; {
    enable = lib.mkEnableOption "The target that will be monitored. Enables promtail and prometheus node exporter for systemd ";

    promtailPort = lib.mkOption {
      type = types.port;
      default = 13200;
      description = "HTTP port for the promtail UI";
    };

    prometheusPort = lib.mkOption {
      type = types.port;
      default = 13150;
      description = "HTTP port for the prometheus exporter";
    };

    lokiAddress = lib.mkOption {
      type = types.str;
      description = "Loki address";
    };
  };

  config = lib.mkIf cfg.enable {
    services.prometheus = {
      exporters = {
        node = {
          enable = true;
          enabledCollectors = [ "systemd" ];
          port = cfg.prometheusPort;
        };
      };
    };

    services.promtail = {
      enable = true;
      configuration = {
        server = {
          http_listen_port = cfg.promtailPort;
          grpc_listen_port = 0;
        };
        positions = {
          filename = "/tmp/positions.yaml";
        };
        clients = [ { url = cfg.lokiAddress; } ];
        scrape_configs = [
          {
            job_name = "journal";
            journal = {
              path = "/var/log/journal";
              max_age = "48h";
              labels = {
                job = "systemd-journal";
                host = hostname;
              };
            };
            relabel_configs = [
              {
                source_labels = [ "__journal__systemd_unit" ];
                target_label = "unit";
              }
              {
                source_labels = [ "__journal__hostname" ];
                target_label = "hostname";
              }
              {
                source_labels = [ "__journal__machine_id" ];
                target_label = "machine_id";
              }
              {
                source_labels = [ "__journal__transport" ];
                target_label = "transport";
              }
            ];
          }
        ];
      };
    };
  };
}
