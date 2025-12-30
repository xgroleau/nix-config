{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.mealie;
in

{
  options.modules.mealie = with lib.types; {
    enable = lib.mkEnableOption "Mealie, a meal planner and grocery shopping list manager";

    port = lib.mkOption {
      type = types.port;
      default = 10400;
      description = "The port to use";
    };

    dataDir = lib.mkOption {
      type = types.str;
      description = "Path to where the data will be stored";
    };

    settings = lib.mkOption {
      type = with lib.types; attrsOf anything;
      default = { };
      description = ''
        Configuration of the Mealie service.

        See [the mealie documentation](https://nightly.mealie.io/documentation/getting-started/installation/backend-config/) for available options and default values.

        In addition to the official documentation, you can set {env}`MEALIE_LOG_FILE`.
      '';
      example = {
        ALLOW_SIGNUP = "false";
      };
    };

    credentialsFile = lib.mkOption {
      type = with lib.types; nullOr path;
      default = null;
      example = "/run/secrets/mealie-credentials.env";
      description = ''
        File containing credentials used in mealie such as {env}`POSTGRES_PASSWORD`
        or sensitive LDAP options.

        Expects the format of an `EnvironmentFile=`, as described by {manpage}`systemd.exec(5)`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.mealie = {
      enable = true;
      port = cfg.port;
      credentialsFile = cfg.credentialsFile;
      settings = {
        DATA_DIR = cfg.dataDir;
        ALLOW_SIGNUP = "false";
        MAX_WORKERS = "1";
        WEB_CONCURRENCY = "1";
      }
      // cfg.settings;

    };

    # TODO: Until https://github.com/NixOS/nixpkgs/pull/309969 is merged
    systemd.services.mealie = {
      serviceConfig = {
        ReadWritePaths = [ cfg.dataDir ];
        StateDirectory = lib.mkForce null;
      };

    };

    systemd.tmpfiles.settings.mealie = {
      "${cfg.dataDir}" = {
        d = {
          mode = "0755";
          user = "mealie";
        };
      };
    };
  };
}
