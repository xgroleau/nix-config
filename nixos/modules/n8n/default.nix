{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.n8n;
in
{
  options.modules.n8n = with lib.types; {
    enable = lib.mkEnableOption "n8n automation server";

    package = lib.mkPackageOption pkgs "n8n" { };

    openFirewall = lib.mkEnableOption "Open the required ports in the firewall";

    port = lib.mkOption {
      type = port;
      default = 5678;
      description = "The port used by the n8n HTTP interface.";
    };

  };

  config = lib.mkIf cfg.enable {
    services.n8n = {
      enable = true;
      openFirewall = cfg.openFirewall;
      environment.N8N_PORT = cfg.port;
      environment.N8N_SECURE_COOKIE = "FALSE";
    };

  };
}
