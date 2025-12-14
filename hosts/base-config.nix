{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  keys = import ../secrets/ssh-keys.nix;
  overlays = import ../overlays { inherit inputs; };
in
{
  config = {

    # Custom modules
    modules = {
      tailscale.enable = true;
    };

    nixpkgs = {
      config = {
        allowUnfree = true;
      };
      overlays = [
        overlays.unstable-packages
      ];
    };

    nix = {

      package = pkgs.nixVersions.latest;
      extraOptions = ''
        experimental-features = nix-command flakes
      '';

      # Avoid always redownloading the registry
      registry.nixpkgsu.flake = inputs.nixpkgs-unstable; # For flake commands
      settings = {
        auto-optimise-store = true;
        trusted-users = [
          "root"
          "@wheel"
        ];
      };
    };

    time.timeZone = "America/Toronto";
    environment.systemPackages = with pkgs; [
      curl
      gitMinimal
      vim
      nano
      wget
    ];

    programs.nix-ld.enable = true;
    programs.zsh.enable = true;
    i18n.defaultLocale = "en_CA.UTF-8";

    # Adding all machines to known host
    programs.ssh.knownHosts = lib.mapAttrs (name: value: { publicKey = value; }) keys.machines;

    users = {
      users.xgroleau = {
        isNormalUser = true;
        shell = pkgs.zsh;
        initialHashedPassword = "$y$j9T$DFrf44y1.2sqKsnal8hCF/$iXy/x/EAGHzU0jEvCs7L/hFu6tSKLQzbcmLL.35nNBA";
        extraGroups = [
          "wheel"
          "builder"
          "audio"
          "networkmanager"

          # For embedded development
          "plugdev"
          "dialout"
        ];

        openssh.authorizedKeys.keys = [ keys.users.xgroleau ];
      };
    };

    networking.nameservers = [
      "1.1.1.1"
      "1.0.0.1"
      "8.8.8.8"
      "8.8.4.4"
    ];

    #Increase number of file descriptor
    systemd.services.nix-daemon.serviceConfig.LimitNOFILE = lib.mkForce 32768;
  };
}
