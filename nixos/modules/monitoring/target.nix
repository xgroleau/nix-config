{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.monitoring.target;
  hostname = config.networking.hostName;
  containerSystemdCfg = cfg.containerSystemd;
  monitoredContainers = builtins.attrNames config.containers;
  containerSystemdEnabled = containerSystemdCfg.enable && monitoredContainers != [ ];
  containerSystemdStateMetric = "nixos_container_systemd_unit_state";
  containerSystemdUpMetric = "nixos_container_systemd_up";
  containerSystemdScrapeTimestampMetric = "nixos_container_systemd_scrape_timestamp_seconds";
  containerSystemdMetricsScript = pkgs.writeShellApplication {
    name = "prometheus-container-systemd-metrics";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.systemd
    ];
    text = ''
      up_metric=${lib.escapeShellArg containerSystemdUpMetric}
      unit_state_metric=${lib.escapeShellArg containerSystemdStateMetric}
      scrape_timestamp_metric=${lib.escapeShellArg containerSystemdScrapeTimestampMetric}
      textfile_directory=${lib.escapeShellArg containerSystemdCfg.textfileDirectory}
      metrics_file="$textfile_directory/container-systemd.prom"
      states=(active activating deactivating failed inactive maintenance reloading refreshing)
      containers=(${lib.escapeShellArgs monitoredContainers})
      tmp_file=

      cleanup() {
        if [ -n "$tmp_file" ]; then
          rm -f "$tmp_file"
        fi
      }

      escape_label() {
        local value="$1"
        value="''${value//\\/\\\\}"
        value="''${value//\"/\\\"}"
        value="''${value//$'\n'/\\n}"
        printf '%s' "$value"
      }

      write_headers() {
        printf '# HELP %s Whether the container systemd manager could be queried.\n' "$up_metric"
        printf '# TYPE %s gauge\n' "$up_metric"
        printf '# HELP %s Systemd unit active state for a NixOS container.\n' "$unit_state_metric"
        printf '# TYPE %s gauge\n' "$unit_state_metric"
        printf '# HELP %s Unix timestamp of the last successful container systemd metrics export.\n' "$scrape_timestamp_metric"
        printf '# TYPE %s gauge\n' "$scrape_timestamp_metric"
      }

      query_container_units() {
        local container="$1"
        systemctl --machine="$container" list-units --type=service --all --output=json --no-pager 2>/dev/null
      }

      unit_rows() {
        jq -r '.[] | select(.unit | endswith(".service")) | [.unit, .active] | @tsv'
      }

      write_container_up() {
        local container="$1"
        local value="$2"
        local escaped_container

        escaped_container="$(escape_label "$container")"
        printf '%s{container="%s"} %s\n' "$up_metric" "$escaped_container" "$value"
      }

      write_unit_states() {
        local container="$1"
        local unit="$2"
        local active_state="$3"
        local escaped_container
        local escaped_unit
        local state
        local value

        escaped_container="$(escape_label "$container")"
        escaped_unit="$(escape_label "$unit")"

        for state in "''${states[@]}"; do
          value=0
          if [ "$state" = "$active_state" ]; then
            value=1
          fi

          printf '%s{container="%s",name="%s",state="%s",type="service"} %s\n' \
            "$unit_state_metric" "$escaped_container" "$escaped_unit" "$state" "$value"
        done
      }

      write_container_metrics() {
        local container="$1"
        local units_json
        local unit
        local active_state

        if ! units_json="$(query_container_units "$container")"; then
          write_container_up "$container" 0
          return
        fi

        write_container_up "$container" 1

        while IFS=$'\t' read -r unit active_state; do
          [ -n "$unit" ] || continue
          write_unit_states "$container" "$unit" "$active_state"
        done < <(printf '%s\n' "$units_json" | unit_rows)
      }

      write_metrics() {
        local container

        write_headers
        printf '%s %s\n' "$scrape_timestamp_metric" "$(date +%s)"
        for container in "''${containers[@]}"; do
          write_container_metrics "$container"
        done
      }

      publish_metrics() {
        tmp_file="$(mktemp "$metrics_file.XXXXXX")"
        trap cleanup EXIT

        write_metrics > "$tmp_file"
        chmod 0644 "$tmp_file"
        mv -f "$tmp_file" "$metrics_file"

        trap - EXIT
        tmp_file=
      }

      publish_metrics
    '';
  };
in
{

  options = {
    modules.monitoring.target = with lib.types; {
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

      containerSystemd = lib.mkOption {
        type = types.submodule {
          options = {
            enable = lib.mkEnableOption "systemd unit monitoring for NixOS nspawn containers";

            linkJournals = lib.mkOption {
              type = types.bool;
              default = true;
              description = "Link selected container journals into the host journal for promtail scraping.";
            };

            interval = lib.mkOption {
              type = types.str;
              default = "30s";
              description = "How often to refresh container systemd metrics.";
            };

            textfileDirectory = lib.mkOption {
              type = types.str;
              default = "/var/lib/prometheus-node-exporter-textfiles";
              description = "Node exporter textfile collector directory for container systemd metrics.";
            };
          };
        };
        default = { };
        description = "Export systemd state and journals from selected NixOS containers.";
      };
    };

    containers = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            config.extraFlags = lib.mkIf (
              cfg.enable && containerSystemdCfg.enable && containerSystemdCfg.linkJournals
            ) [ "--link-journal=try-host" ];
          }
        )
      );
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        services.prometheus = {
          exporters = {
            node = {
              enable = true;
              enabledCollectors = [ "systemd" ];
              extraFlags = lib.mkIf containerSystemdEnabled [
                "--collector.textfile.directory=${containerSystemdCfg.textfileDirectory}"
              ];
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
              filename = "/var/lib/promtail/positions.yaml";
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
                    source_labels = [ "__journal__machine_name" ];
                    target_label = "container";
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
      }

      (lib.mkIf containerSystemdEnabled {
        systemd.tmpfiles.settings."prometheus-container-systemd-metrics" = {
          "${containerSystemdCfg.textfileDirectory}" = {
            d = {
              mode = "755";
              user = "root";
              group = "root";
            };
          };
        };

        systemd.services.prometheus-container-systemd-metrics = {
          description = "Export systemd service states for NixOS containers";
          after = map (name: "container@${name}.service") monitoredContainers;
          wantedBy = map (name: "container@${name}.service") monitoredContainers;
          serviceConfig = {
            Type = "oneshot";
            User = "root";
            Group = "root";
            PrivateTmp = true;
            ProtectHome = true;
            ProtectSystem = "strict";
            ReadWritePaths = [ containerSystemdCfg.textfileDirectory ];
            NoNewPrivileges = true;
            LockPersonality = true;
            MemoryDenyWriteExecute = true;
            RestrictAddressFamilies = [ "AF_UNIX" ];
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
          };
          script = "${containerSystemdMetricsScript}/bin/prometheus-container-systemd-metrics";
        };

        systemd.timers.prometheus-container-systemd-metrics = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "1m";
            OnUnitActiveSec = containerSystemdCfg.interval;
            AccuracySec = "5s";
          };
        };
      })
    ]
  );
}
