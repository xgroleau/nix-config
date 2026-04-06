{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.modules.valheim;
  join = builtins.concatStringsSep " ";
in
{

  options.modules.valheim = with lib.types; {
    enable = lib.mkEnableOption "valheim";

    openFirewall = lib.mkEnableOption "Open the required ports in the firewall";

    restart = lib.mkEnableOption "Restart the service every night for updates";

    user = lib.mkOption {
      type = lib.types.str;
      default = "valheim";
      description = "User account under which valheim runs";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "valheim";
      description = "Group under which valheim runs";
    };

    name = lib.mkOption {
      type = lib.types.str;
      default = "valheim";
      description = "Name for the server";
    };

    password = lib.mkOption {
      type = lib.types.str;
      default = "valheim";
      description = "Password for the server";
    };

    restartTime = lib.mkOption {
      type = lib.types.str;
      default = "*-*-* 04:00:00";
      description = "When to do the restart. Uses systemd timer calendar format";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/valheim";
      description = "Where on disk to store your valheim directory";
    };

    port = lib.mkOption {
      type = types.port;
      default = 2456;
      description = "the port to use";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.${cfg.user} = {
      inherit (cfg) group;
      home = cfg.dataDir;
      createHome = true;
      isSystemUser = true;
    };
    users.groups.${cfg.group} = { };

    systemd = lib.mkMerge [
      {
        services.valheim = {
          after = [ "network.target" ];
          requires = [ "network.target" ];
          wantedBy = [ "multi-user.target" ];

          serviceConfig = {
            TimeoutStartSec = "20min";
            ExecStartPre = join [
              "${pkgs.steamcmd}/bin/steamcmd"
              "+force_install_dir ${cfg.dataDir}"
              "+login anonymous"
              "+app_update 896660"
              "-beta public-test"
              "-betapassword yesimadebackups"
              "validate"
              "+quit"
            ];
            ExecStart = join [
              "${pkgs.steam-run}/bin/steam-run ${cfg.dataDir}/valheim_server.x86_64"
              "-port ${toString cfg.port}"
              "-nographics"
              "-batchmode"
              "-name ${cfg.name}"
              "-world ${cfg.name}"
              "-password ${cfg.password}"
              "-public 0"
            ];

            User = cfg.user;
            Restart = "always";
            WorkingDirectory = cfg.dataDir;
          };

          environment = {
            LD_LIBRARY_PATH = "linux64:${pkgs.glibc}/lib";
            SteamAppId = "892970";
          };
        };
      }

      # Restart the service
      (lib.mkIf cfg.restart {
        services.valheim-restart = {
          description = "Restart valheim";
          wantedBy = [ "multi-user.target" ];
          script = "systemctl restart valheim.service ";
          serviceConfig = {
            User = "root";
            Type = "oneshot";
            RemainAfterExit = "true";

            # Valheim needs sigint to to shutdown gracefully for some reason
            # https://valheimbugs.featureupvote.com/suggestions/159711/dedicated-server-does-not-save-world-on-sigterm
            KillSignal = "SIGINT";
          };
        };

        timers.valheim-restart = {
          wantedBy = [ "timers.target" ];
          partOf = [ "valheim-restart.service" ];
          timerConfig = {
            OnCalendar = [ cfg.restartTime ];
          };
        };
      })
    ];

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedUDPPorts = [
        cfg.port
        (cfg.port + 1) # For steam discovery
      ];
    };
  };
}
