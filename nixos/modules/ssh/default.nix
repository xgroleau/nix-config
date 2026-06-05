{
  config,
  lib,
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
      openFirewall = false;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
    };
  };
}
