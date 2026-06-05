{
  config,
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
    ./disko.nix
    ./preservation.nix
  ];

  config = {
    modules = {
      home = {
        enable = true;
        username = "xgroleau";
        profile = "minimal";
      };

      ssh.enable = true;

      tailscale = {
        authKeyFile = "/persist/secrets/tailscale-authkey";
      };

      secrets.enable = true;

      monitoring = {
        server = {
          enable = true;
          prometheusScrapeUrls = [ "sheogorath:13150" ];
          prometheusPort = 13020;
          grafanaPort = 13010;
          grafanaAdminPasswordFile = config.age.secrets.grafanaAdminPw.path;
          grafanaSecretKeyFile = config.age.secrets.grafanaSecretKey.path;
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

    networking = {
      hostName = hostname;
      hostId = "5dd3d7e6";
    };

    system.stateVersion = "25.05";
  };
}
