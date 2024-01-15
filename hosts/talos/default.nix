{ config, pkgs, ... }:

{
  imports = [ ../base-config.nix ./disko.nix ./hardware-configuration.nix ];

  config = {
    # Custom modules
    modules = {
      home.username = "xgroleau";
      home.profile = "minimal";
      networking.ssh.enable = true;
      secrets.enable = true;

      services = {
        docker.enable = true;
        media-server = {
          enable = true;
          downloadPath = "/storage/vault/downloads";
          ovpnFile = config.age.secrets.piaOvpn.path;
          ovpnUsername = config.age.secrets.piaUsername.path;
          ovpnPassword = config.age.secrets.piaPassword.path;
        };
      };
    };

    # Use the systemd-boot EFI boot loader.
    boot = {
      loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = true;
      };
    };

    networking = {
      hostId = "819a6cd7";
      hostName = "talos";
      interfaces.enp0s25.useDHCP = true;
    };

    system.stateVersion = "24.05";
  };
}
