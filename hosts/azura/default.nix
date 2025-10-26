{ config, pkgs, ... }:

{
  imports = [
    ../desktop.nix
    ./hardware-configuration.nix
  ];

  config = {
    # Custom modules
    modules = {
      home = {
        enable = true;
        username = "xgroleau";
        profile = "desktop";
      };

      ssh.enable = true;
      kdeconnect.enable = true;
      docker.enable = true;

      # Let home manager setup the session and the X11 windowing system.
      xserver.home-manager = true;
    };

    networking = {
      hostName = "azura";
      networkmanager.enable = true;
      interfaces.enp12s0.useDHCP = true;
    };

    programs.steam.enable = false;

    # Dualbooting, avoids time issues
    time.hardwareClockInLocalTime = true;

    services.zerotierone.enable = true;

    system.stateVersion = "25.05";
  };
}
