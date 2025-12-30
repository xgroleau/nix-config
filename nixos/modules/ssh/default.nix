{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.ssh;
in
{

  options.modules.ssh = {
    enable = lib.mkEnableOption "Enable a ssh server";
  };

  config = lib.mkIf cfg.enable {
    services.openssh = {
      enable = true;
      openFirewall = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
    };
  };
}
