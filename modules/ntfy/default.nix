{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.modules.ntfy;
in
{

  imports = [ ];

  options.modules.ntfy = with lib.types; {
    enable = lib.mkEnableOption ''Enables the ntfy module to notify services'';

    url = lib.mkOption {
      type = types.str;
      description = "Url of ntfy";
    };

    envFile = lib.mkOption {
      type = with lib.types; nullOr path;
      default = null;
      example = "/run/secrets/ntfy";
      description = "Path to the environment file";
    };

    dataDir = lib.mkOption {
      type = types.str;
      description = "Path to where the cache data will be stored";
    };

    port = lib.mkOption {
      type = types.port;
      default = 8080;
      description = "the port for http access";
    };

  };

  # We use a contianer so other services can have a different PG version
  config = lib.mkIf cfg.enable {
    services.ntfy-sh = {
      enable = true;
      environmentFile = cfg.envFile;
      settings = {
        base-url = cfg.url;
        listen-http = ":${toString cfg.port}";
        auth-file = "${cfg.dataDir}/auth.db";
        auth-default-access = "deny-all";
        cache-file = "${cfg.dataDir}/cache/cache.db";
        attachment-cache-dir = "${cfg.dataDir}/cache/attachments";
        enable-login = true;
        enable-reservations = true;
      };

    };

    systemd.tmpfiles.settings.ntfy = {
      "${cfg.dataDir}" = {
        d = {
          mode = "0750";
          user = config.services.ntfy-sh.user;
          group = config.services.ntfy-sh.group;
        };
      };

      "${cfg.dataDir}/cache" = {
        d = {
          mode = "0750";
          user = config.services.ntfy-sh.user;
          group = config.services.ntfy-sh.group;
        };
      };
      "${cfg.dataDir}/cache/attachments" = {
        d = {
          mode = "0750";
          user = config.services.ntfy-sh.user;
          group = config.services.ntfy-sh.group;
        };
      };
    };
  };
}
