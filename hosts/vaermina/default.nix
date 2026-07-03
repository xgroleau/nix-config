{ pkgs, ... }:
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

      home = {
        enable = true;
        username = "xgroleau";
        profile = "minimal";
      };
    };

    # Support for the controllers and more
    hardware = {
      xone.enable = true;
      xpadneo.enable = true;
      uinput.enable = true;
      steam-hardware.enable = true;

    };

    # decky-loader pulls in pnpm at build time; upstream package is flagged insecure
    nixpkgs.config.permittedInsecurePackages = [ "pnpm-9.15.9" ];

    # Steam deck experience
    jovian = {
      decky-loader.enable = true;
      steam = {
        autoStart = true;
        desktopSession = "plasma";
        enable = true;
        user = "console";
      };
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
        retroarch-full
        firefox
        mesa-demos
        mangohud
        vulkan-tools
        wine
        winetricks
      ];
    };

    users.deterministicIds.console = {
      uid = 1001;
      gid = 1001;
    };

    users.users.console = {
      isNormalUser = true;
      autoSubUidGidRange = false;
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

    networking = {
      hostName = "vaermina";
      networkmanager.enable = true;
      interfaces.enp1s0.useDHCP = true;
      interfaces.wlp2s0.useDHCP = true;
    };

    system.stateVersion = "25.05";
  };
}
