{ config, pkgs, ... }:

let hostname = "jyggalag";
in {
  imports = [ ../base-config.nix ./disko.nix ./hardware-configuration.nix ];

  config = {
    # Custom modules
    modules = {
      home.username = "xgroleau";
      home.profile = "minimal";
      ssh.enable = true;
      secrets.enable = true;

      authentik = {
        enable = true;
        envFile = config.age.secrets.authentikEnv.path;
        dataDir = "/data/authentik";
        port = 9000;
      };

      ocis = {
        enable = true;
        dataDir = "/documents/ocis";
        configDir = "/vault/ocis";
        port = 9200;
      };

      media-server = {
        enable = true;
        data = "/vault/media-server";
        download = "/media/deluge-downloads";
        ovpnFile = config.age.secrets.piaOvpn.path;
      };

      palworld = {
        enable = true;
        dataDir = "/data/palworld";
        port = 8211;
      };

      pomerium = {
        enable = true;
        envFile = config.age.secrets.pomeriumIdentityProvider.path;
      };
    };
    networking.firewall.enable = false;
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };

    # Use the systemd-boot EFI boot loader.
    boot = {
      loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = true;
      };
    };

    networking = {
      useDHCP = true;
      hostId = "819a6cd7";
      hostName = "sheogorath";
    };

    system.stateVersion = "24.05";
  };
}
