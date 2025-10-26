{ config, pkgs, ... }:

{
  imports = [
    ../desktop.nix
    ./hardware-configuration.nix
  ];

  config = {
    modules = {
      home = {
        enable = true;
        username = "xgroleau";
        profile = "desktop";
      };

      docker.enable = true;
      kdeconnect.enable = true;

      # Let home manager setup the session and the X11 windowing system.
      xserver.home-manager = true;
    };

    networking = {
      hostName = "namira";
      networkmanager.enable = true;
    };

    # Dualbooting, avoids time issues
    time.hardwareClockInLocalTime = true;

    services = {
      # Enable touchpad
      libinput.enable = true;
    };

    # For broadcom ble chip
    hardware.enableAllFirmware = true;

    system.stateVersion = "25.05";
  };
}
