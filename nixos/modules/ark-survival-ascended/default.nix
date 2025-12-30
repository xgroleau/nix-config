{
  config,
  lib,
  pkgs,
  ...
}:

let

  cfg = config.modules.arkSurvivalAscended;

  containerBackendName = config.virtualisation.oci-containers.backend;

  containerBackend = pkgs."${containerBackendName}" + "/bin/" + containerBackendName;
in

{
  options.modules.arkSurvivalAscended = with lib.types; {
    enable = lib.mkEnableOption "Enables ark survival ascended server";

    openFirewall = lib.mkEnableOption "Open the required ports in the firewall";

    port = lib.mkOption {
      type = types.port;
      default = 7777;
      description = "The port to use";
    };

    dataDir = lib.mkOption {
      type = types.str;
      description = "Path to where the server data will be stored";
    };

  };

  config = lib.mkIf cfg.enable {

    virtualisation.oci-containers.containers = {
      asa-1 = {
        autoStart = true;
        image = "mschnitzer/asa-linux-server:latest";
        entrypoint = "/usr/bin/start_server";
        user = "gameserver";
        volumes = [
          "/etc/localtime:/etc/localtime:ro"
          "${cfg.dataDir}/steam:/home/gameserver/Steam:rw"
          "${cfg.dataDir}/steamcmd:/home/gameserver/steamcmd:rw"
          "${cfg.dataDir}/server:/home/gameserver/server-files:rw"
          "${cfg.dataDir}/cluster:/home/gameserver/cluster-shared:rw"
        ];

        environment = {
          PUID = "25000";
          PGID = "25000";

          ASA_START_PARAMS = "TheCenter_WP?listen?Port=7777?RCONPort=27020?RCONEnabled=True -WinLiveMaxPlayers=50 -clusterid=default -ClusterDirOverride=\"/home/gameserver/cluster-shared\"";
          ENABLE_DEBUG = "0";
        };

        ports = [ "${toString cfg.port}:7777/udp" ];
      };
    };

    networking.firewall = {
      allowedUDPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
    };

    systemd.tmpfiles.settings.arkSurvivalAscended = {
      "${cfg.dataDir}/steam" = {
        d = {
          mode = "0777";
          user = "25000";
          group = "25000";
        };
      };
      "${cfg.dataDir}/steamcmd" = {
        d = {
          mode = "0777";
          user = "25000";
          group = "25000";
        };
      };
      "${cfg.dataDir}/server" = {
        d = {
          mode = "0777";
          user = "25000";
          group = "25000";
        };
      };
      "${cfg.dataDir}/cluster" = {
        d = {
          mode = "0777";
          user = "25000";
          group = "25000";
        };
      };

    };
  };
}
