{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.msmtp;
in
{

  options.modules.msmtp = with lib.types; {
    enable = lib.mkEnableOption "Enables msmtp to send emails and notifications. Also enables system notification to an email";

    host = lib.mkOption {
      type = types.str;
      description = "Host to use";
    };

    from = lib.mkOption {
      type = types.str;
      description = "Email to use to send";
    };

    username = lib.mkOption {
      type = types.str;
      description = "Username to authenticate";
    };

    passwordFile = lib.mkOption {
      type = types.str;
      description = "Path to the password file";
    };

    port = lib.mkOption {
      type = types.port;
      default = 587;
      description = "The port to use to send the email";
    };

    to = lib.mkOption {
      type = types.str;
      description = "Email to receive system notificaiton (e.g. zfs errors)";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.msmtp = {
      enable = true;
      setSendmail = true;
      defaults = {
        aliases = "/etc/aliases";
      };
      accounts = {
        default = {
          auth = true;
          tls = true;
          port = cfg.port;
          from = cfg.from;
          host = cfg.host;
          user = cfg.username;
          passwordeval = "cat ${cfg.passwordFile}";
        };
      };
    };

    environment.etc = {
      "aliases" = {
        text = ''
          root: ${cfg.from}
        '';
        mode = "0644";
      };
    };

    services.zfs.zed = {
      enableMail = false;
      settings = {
        ZED_DEBUG_LOG = "/tmp/zed.debug.log";
        ZED_EMAIL_ADDR = [ cfg.to ];
        ZED_EMAIL_PROG = "${pkgs.msmtp}/bin/msmtp";
        ZED_EMAIL_OPTS = "@ADDRESS@";

        ZED_NOTIFY_INTERVAL_SECS = 3600;
        ZED_NOTIFY_VERBOSE = false;

        ZED_USE_ENCLOSURE_LEDS = true;
        ZED_SCRUB_AFTER_RESILVER = true;
      };
    };
  };
}
