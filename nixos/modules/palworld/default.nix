{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.modules.palworld;
  join = builtins.concatStringsSep " ";
in
{

  options.modules.palworld = with lib.types; {
    enable = lib.mkEnableOption "palworld";

    openFirewall = lib.mkEnableOption "Open the required ports in the firewall";

    restart = lib.mkEnableOption "Restart the service every night for updates";

    user = lib.mkOption {
      type = lib.types.str;
      default = "palworld";
      description = "User account under which palworld runs";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "palworld";
      description = "Group under which palworld runs";
    };

    restartTime = lib.mkOption {
      type = lib.types.str;
      default = "*-*-* 04:00:00";
      description = "When to do the restart. Uses systemd timer calendar format";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/palworld";
      description = "Where on disk to store your palworld directory";
    };

    port = lib.mkOption {
      type = types.port;
      default = 8211;
      description = "the port to use";
    };

    maxPlayers = lib.mkOption {
      type = types.number;
      default = 32;
      description = "The max amount of players to support";
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
        services.palworld = {
          after = [ "network.target" ];
          requires = [ "network.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            TimeoutStartSec = "20min";
            ExecStartPre = join [
              "${pkgs.steamcmd}/bin/steamcmd"
              "+force_install_dir ${cfg.dataDir}"
              "+login anonymous"
              "+app_update 2394010"
              "+quit"
            ];
            ExecStart = join [
              "${pkgs.steam-run}/bin/steam-run ${cfg.dataDir}/Pal/Binaries/Linux/PalServer-Linux-Test Pal"
              "--port ${toString cfg.port}"
              "--players ${toString cfg.maxPlayers}"
              "--useperfthreads"
              "-NoAsyncLoadingThread"
              "-UseMultithreadForDS"
            ];

            # Palworld has a massive memoryleak, let's limit the memory to keep the system up
            MemoryMax = "16G";

            User = cfg.user;
            Restart = "always";
            WorkingDirectory = cfg.dataDir;
          };

          environment = {
            # linux64 directory is required by palworld.
            LD_LIBRARY_PATH = with pkgs; lib.makeLibraryPath [ glibc ];
          };
        };
      }

      # Restart the service
      (lib.mkIf cfg.restart {
        services.palworld-restart = {
          description = "Restart palworld";
          wantedBy = [ "multi-user.target" ];
          script = "systemctl restart palworld.service ";
          serviceConfig = {
            User = "root";
            Type = "oneshot";
            RemainAfterExit = "true";
          };
        };

        timers.palworld-restart = {
          wantedBy = [ "timers.target" ];
          partOf = [ "palworld-restart.service" ];
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
