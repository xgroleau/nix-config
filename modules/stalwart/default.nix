{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.stalwart;
in
{

  options.modules.stalwart = with lib.types; {
    enable = lib.mkEnableOption ''Enables the ntfy module to notify services'';

    openFirewall = lib.mkEnableOption "Open the required ports in the firewall";

    dataDir = lib.mkOption {
      type = types.str;
      description = "Path to where the data will be stored";
    };

    credentials = lib.mkOption {
      description = "Credentials, each one of them must be a string to a file containing the secret";
      type = types.submodule {
        environmentFiles = lib.mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "List of environment files to pass for secrets, oidc and others";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.stalwart-mail = {
      enable = true;

      dataDir = cfg.dataDir;
      openFirewall = cfg.openFirewall;
      settings = {
        server = {
          hostname = "mx1.example.org";
          tls = {
            enable = true;
            implicit = true;
          };
          listener = {
            smtp = {
              protocol = "smtp";
              bind = "[::]:42225";
            };
            submissions = {
              bind = "[::]:42465";
              protocol = "smtp";
            };
            imaps = {
              bind = "[::]:42993";
              protocol = "imap";
            };
            # jmap = {
            #   bind = "[::]:42080";
            #   url = "https://mail.example.org";
            #   protocol = "jmap";
            # };
            management = {
              bind = [ "[::]:42080" ];
              protocol = "http";
            };
          };
        };
      };

    };

    # Create the folder if it doesn't exist
    systemd.tmpfiles.settings.stalwart = {
      "${cfg.dataDir}" = {
        d = {
          user = "stalwart-mail";
          group = "stalwart-mail";
          mode = "750";
        };
      };
    };

  };
}
