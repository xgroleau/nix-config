{ config, pkgs, ... }:
{

  imports = [
    ../base-config.nix
    ./disko.nix
    ./hardware-configuration.nix
  ];

  config = {

    #Custom modules
    modules = {
      ssh.enable = true;
    };

    # Support for the controllers and more
    hardware = {
      xone.enable = true;
      xpadneo.enable = true;
      uinput.enable = true;
      steam-hardware.enable = true;

    };

    # Steam deck experience
    jovian = {
      decky-loader.enable = true;
      steam.autoStart = true;
      steam.desktopSession = "plasma";
      steam.enable = true;
      steam.user = "console";
    };

    # Other services
    services = {
      desktopManager.plasma6.enable = true;
      libinput.enable = true;
      joycond.enable = true;

      udev.extraRules = ''
        SUBSYSTEM=="vchiq",GROUP="video",MODE="0660"
        KERNEL=="event*", ATTRS{id/product}=="9400", ATTRS{id/vendor}=="18d1", MODE="0660", GROUP="plugdev", SYMLINK+="input/by-id/stadia-controller-$kernel"
      '';

    };

    environment = {
      # Couple of packages
      systemPackages = with pkgs; [
        retroarchFull
        firefox
        glxinfo
        mangohud
        vulkan-tools
        wine
        winetricks
      ];
    };

    users.users.console = {
      isNormalUser = true;
      extraGroups = [
        "adm"
        "audio"
        "dialout"
        "input"
        "kvm"
        "networkmanager"
        "plugdev"
        "systemd-journal"
        "users"
        "video"
      ];
    };

    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };

    networking = {
      hostName = "vaermina";
      networkmanager.enable = true;
      interfaces.enp1s0.useDHCP = true;
      interfaces.wlp2s0.useDHCP = true;
    };

    system.stateVersion = "25.05";
  };
}
