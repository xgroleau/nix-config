{
  config,
  pkgs,
  lib,
  ...
}:

let
  hostname = "jyggalag";
in
{
  imports = [
    ../base-config.nix
    ../server-config.nix
    ./hardware-configuration.nix
  ];

  config = {
    modules = {
      home = {
        enable = true;
        username = "xgroleau";
        profile = "minimal";
      };

      ssh.enable = true;

      secrets.enable = true;

      monitoring = {
        server = {
          enable = true;
          prometheusScrapeUrls = [ "sheogorath:13150" ];
          prometheusPort = 13020;
          grafanaPort = 13010;
          lokiPort = 13100;
          alerting = {
            enable = true;
            envFile = config.age.secrets.alertmanagerEnv.path;
            emailTo = "xavgroleau@gmail.com";
            port = 13024;
          };
        };
      };

      ollama = {
        enable = true;
        port = 11434;
      };
    };

    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };

    boot = {
      loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = true;
      };
    };

    networking.hostName = hostname;

    system.stateVersion = "25.05";
  };
}
