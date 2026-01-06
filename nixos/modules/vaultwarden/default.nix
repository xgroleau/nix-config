{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.vaultwarden;
in

{
  options.modules.vaultwarden = with lib.types; {
    enable = lib.mkEnableOption "Vaultwarden, a bitwarden compatible backend";

    port = lib.mkOption {
      type = types.port;
      default = 10400;
      description = "The port to use";
    };

    domain = lib.mkOption {
      type = types.str;
      description = "Domain of the vaultwarden instance.";
    };

    dataDir = lib.mkOption {
      type = types.str;
      description = "Path to where the data will be stored";
    };

    envFile = lib.mkOption {
      type = types.str;
      description = ''
        Path to where the secrets environment file 
      '';
    };

  };

  config = lib.mkIf cfg.enable {
    services.vaultwarden = {
      enable = true;
      domain = cfg.domain;
      package = pkgs.unstable.vaultwarden;
      webVaultPackage = pkgs.unstable.webVaultPackage;
      environmentFile = cfg.envFile;
      dbBackend = "sqlite";
      config = {
        SIGNUPS_ALLOWED = false;
        ROCKET_ADDRESS = "0.0.0.0";
        ROCKET_PORT = cfg.port;
        ROCKET_LOG = "critical";
      };
    };

    # TODO: Remove when https://github.com/NixOS/nixpkgs/issues/289473
    systemd.services.backup-vaultwarden.environment.DATA_FOLDER = lib.mkForce cfg.dataDir;

    systemd.tmpfiles.settings.vaultwarden = {
      "${cfg.dataDir}" = {
        d = {
          mode = "0700";
          user = config.users.users.vaultwarden.name;
          group = config.users.groups.vaultwarden.name;
        };
      };
    };
  };
}
