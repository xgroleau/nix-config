{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.attic;
in

{
  options.modules.attic = {
    enable = lib.mkEnableOption "Monitoring module, will monitor another server, see config.modules.monitoring.target for the target system to monitor";

    port = lib.mkOption {
      type = lib.types.port;
      default = 14000;
      description = "The port to use";
    };

    openFirewall = lib.mkEnableOption "Open the required ports in the firewall";

    dataDir = lib.mkOption {
      type = lib.types.str;
      description = "Path where the data and the sklite will be stored";

    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      example = "/etc/atticd.env";
      description = ''
        Path to an EnvironmentFile containing required environment
        variables:

        - ATTIC_SERVER_TOKEN_HS256_SECRET_BASE64: The Base64-encoded version of the
          HS256 JWT secret. Generate it with `openssl rand 64 | base64 -w0`.
      '';
    };

  };

  config = lib.mkIf cfg.enable {

    environment.systemPackages = with pkgs; [ attic-server ];

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [
        cfg.port
      ];
    };

    services.atticd = {

      enable = true;
      user = "atticd";
      group = "atticd";

      environmentFile = cfg.environmentFile;

      # Replace with absolute path to your credentials file

      settings = {
        listen = "[::]:${toString cfg.port}";

        require-proof-of-possession = false;

        chunking = {
          nar-size-threshold = 64 * 1024; # 64 KiB
          min-size = 16 * 1024; # 16 KiB
          avg-size = 64 * 1024; # 64 KiB
          max-size = 256 * 1024; # 256 KiB
        };

        storage = {
          type = "local";
          path = "${cfg.dataDir}";
        };

        compression = {
          type = "zstd";
        };

        garbage-collection = {
          interval = "12 hours";
          default-retention-period = "1 months";
        };

      };
    };

    systemd.tmpfiles.settings.attic = {
      "${cfg.dataDir}/" = {
        d = {
          mode = "0777";
          user = "root";
        };
      };
    };
  };
}
