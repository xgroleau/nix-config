{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.duckdns;
in
{

  options.modules.duckdns = with lib.types; {
    enable = lib.mkEnableOption "Duckdns configuration, enable to register a domain to duckdns";

    domain = lib.mkOption {
      type = types.nonEmptyStr;
      description = "The domain to register";
    };

    tokenFile = lib.mkOption {
      type = types.str;
      description = ''
        The full path to a file which contains the token for the domain.
         The file should contain exactly one line with the token without any newline.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.timers.duckdns = {
      wantedBy = [ "timers.target" ];
      wants = [ "network-online.target" ];
      after = [
        "network.target"
        "network-online.target"
      ];
      timerConfig = {
        OnBootSec = "5m";
        OnUnitActiveSec = "5m";
        Unit = "duckdns.service";
      };
    };

    systemd.services.duckdns = {
      wants = [ "network-online.target" ];
      after = [
        "network.target"
        "network-online.target"
      ];
      script = ''
        set -eu
        ${pkgs.curl}/bin/curl "https://www.duckdns.org/update?domains=${cfg.domain}&token=$(${pkgs.coreutils}/bin/cat $CREDENTIALS_DIRECTORY/duckdnsToken)&ip="
      '';
      serviceConfig = {
        Type = "oneshot";
        DynamicUser = true;
        LoadCredential = "duckdnsToken:${cfg.tokenFile}";
      };
    };
  };
}
