{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.modules.abioticFactor;
  join = builtins.concatStringsSep " ";

  serverExe = "${cfg.dataDir}/AbioticFactor/Binaries/Win64/AbioticFactorServer-Win64-Shipping.exe";

  startScript = pkgs.writeShellScript "abiotic-factor-start" ''
    args=(
      ${serverExe}
      -log
      -useperfthreads
      -NoAsyncLoadingThread
      -PORT=${toString cfg.port}
      -QueryPort=${toString cfg.queryPort}
      -MaxServerPlayers=${toString cfg.maxPlayers}
      -SteamServerName="${cfg.name}"
      -WorldSaveName="${cfg.worldName}"

      # Undocumented upstream, but every working wine recipe passes it
      -tcp

      ${join cfg.extraArgs}
    )

    ${lib.optionalString (cfg.passwordFile != null) ''
      args+=(-ServerPassword="$(cat "$CREDENTIALS_DIRECTORY/password")")
    ''}
    ${lib.optionalString (cfg.adminPasswordFile != null) ''
      args+=(-AdminPassword="$(cat "$CREDENTIALS_DIRECTORY/admin-password")")
    ''}

    exec ${lib.getExe pkgs.wine64} "''${args[@]}"
  '';
in
{

  options.modules.abioticFactor = with lib.types; {
    enable = lib.mkEnableOption "abiotic factor";

    openFirewall = lib.mkEnableOption "Open the required ports in the firewall";

    restart = lib.mkEnableOption "Restart the service every night for updates";

    user = lib.mkOption {
      type = str;
      default = "abiotic-factor";
      description = "User account under which abiotic factor runs";
    };

    group = lib.mkOption {
      type = str;
      default = "abiotic-factor";
      description = "Group under which abiotic factor runs";
    };

    name = lib.mkOption {
      type = str;
      default = "abiotic-factor";
      description = "Name of the server as shown in the steam server browser";
    };

    worldName = lib.mkOption {
      type = str;
      default = "Cascade";
      description = "Save folder to load, a new world is created if it doesn't exist yet";
    };

    passwordFile = lib.mkOption {
      type = nullOr str;
      default = null;
      description = "Path to a file containing the server password. Anyone can join when null";
    };

    adminPasswordFile = lib.mkOption {
      type = nullOr str;
      default = null;
      description = "Path to a file containing the password used to authenticate in game admin commands";
    };

    restartTime = lib.mkOption {
      type = str;
      default = "*-*-* 04:00:00";
      description = "When to do the restart. Uses systemd timer calendar format";
    };

    dataDir = lib.mkOption {
      type = str;
      default = "/var/lib/abiotic-factor";
      description = "Where on disk to store the server files, the wine prefix and the saves";
    };

    port = lib.mkOption {
      type = port;
      default = 7777;
      description = "the port to use";
    };

    queryPort = lib.mkOption {
      type = port;
      default = 27015;
      description = "the port steam uses to advertise the server";
    };

    maxPlayers = lib.mkOption {
      type = ints.between 1 24;
      default = 6;
      description = "The max amount of players to support, the game warns above 6";
    };

    extraArgs = lib.mkOption {
      type = listOf str;
      default = [ ];
      example = [ "-AdminIniPath=Admin.ini" ];
      description = "Extra launch parameters passed to the server";
    };
  };

  config = lib.mkIf cfg.enable {
    users.deterministicIds.${cfg.user} = {
      uid = 963;
      gid = 963;
    };

    users.users.${cfg.user} = {
      inherit (cfg) group;
      home = cfg.dataDir;
      createHome = true;
      isSystemUser = true;
    };
    users.groups.${cfg.group} = { };

    systemd = lib.mkMerge [
      {
        services.abiotic-factor = {
          after = [ "network.target" ];
          requires = [ "network.target" ];
          wantedBy = [ "multi-user.target" ];

          serviceConfig = {
            TimeoutStartSec = "20min";

            # There is no linux build, so we pull the windows files and run them under wine
            ExecStartPre = join [
              "${pkgs.steamcmd}/bin/steamcmd"
              "+@sSteamCmdForcePlatformType windows"
              "+force_install_dir ${cfg.dataDir}"
              "+login anonymous"
              "+app_update 2857200"
              "validate"
              "+quit"
            ];

            # The passwords are only taken as CLI arguments, read them at
            # runtime to keep them out of the nix store
            ExecStart = startScript;
            LoadCredential =
              lib.optional (cfg.passwordFile != null) "password:${cfg.passwordFile}"
              ++ lib.optional (cfg.adminPasswordFile != null) "admin-password:${cfg.adminPasswordFile}";

            # Wine forwards SIGINT as a console ctrl-c, which lets the server save before exiting
            KillSignal = "SIGINT";
            TimeoutStopSec = "2min";

            User = cfg.user;
            Restart = "always";
            WorkingDirectory = cfg.dataDir;
          };

          environment = {
            WINEPREFIX = "${cfg.dataDir}/.wine";
            WINEARCH = "win64";

            # Headless, the mono and gecko install prompts would block the service forever
            WINEDLLOVERRIDES = "mscoree,mshtml=";
            WINEDEBUG = "-all";
          };
        };
      }

      # Restart the service
      (lib.mkIf cfg.restart {
        services.abiotic-factor-restart = {
          description = "Restart abiotic factor";
          script = "systemctl restart abiotic-factor.service";
          serviceConfig = {
            User = "root";
            Type = "oneshot";
            RemainAfterExit = "true";
          };
        };

        timers.abiotic-factor-restart = {
          wantedBy = [ "timers.target" ];
          partOf = [ "abiotic-factor-restart.service" ];
          timerConfig = {
            OnCalendar = [ cfg.restartTime ];
          };
        };
      })
    ];

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
      allowedUDPPorts = [
        cfg.port
        cfg.queryPort
      ];
    };
  };
}
