{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../base-config.nix
    ../server-config.nix
    ./disko.nix
    ./hardware-configuration.nix
    ./persistence.nix
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
    };

    networking = {
      hostName = "molag";
      useDHCP = true;
    };

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.initrd.systemd.enable = true;
    services.journald.extraConfig = ''
      SystemMaxUse=2G
      SystemMaxFileSize=200M
    '';

    system.stateVersion = "25.11";
  };
}
