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

  imports = [
    ./aerospace
    ./home
    ./homebrew
  ];

  config = {
    modules.darwin = {
      home = {
        enable = true;
        username = "xgroleau";
      };
      homebrew.enable = true;
      aerospace.enable = true;
    };

    nixpkgs = {
      config.allowUnfree = true;
      hostPlatform = "aarch64-darwin";
      overlays = [ overlays.unstable-packages ];
    };

    nix = {
      package = pkgs.nixVersions.latest;
      extraOptions = ''
        experimental-features = nix-command flakes
      '';

      # Avoid always redownloading the registry
      registry.nixpkgsu.flake = inputs.nixpkgs-unstable; # For flake commands
      settings.trusted-users = [ "@admin" ];
    };

    # Adding all machines to known host
    programs.ssh.knownHosts = lib.mapAttrs (name: value: { publicKey = value; }) keys.machines;

    system = {
      primaryUser = "xgroleau";
      startup.chime = false;

      defaults = {
        dock = {
          autohide = true;
          show-recents = false;
        };

        trackpad = {
          Clicking = true;
          TrackpadRightClick = true;
          TrackpadThreeFingerDrag = true;
        };

        NSGlobalDomain = {
          # UI settings
          AppleEnableSwipeNavigateWithScrolls = true;
          AppleInterfaceStyle = "Dark";
          AppleMetricUnits = 1;
          AppleShowAllExtensions = true;
          AppleTemperatureUnit = "Celsius";
          "com.apple.sound.beep.feedback" = 0;

          # Trackpad
          "com.apple.swipescrolldirection" = true;

          # Keyboard
          KeyRepeat = 2;
          InitialKeyRepeat = 15;
          AppleKeyboardUIMode = 3;
          ApplePressAndHoldEnabled = false;
          "com.apple.keyboard.fnState" = false;

          # Char Substitution
          NSAutomaticCapitalizationEnabled = false;
          NSAutomaticDashSubstitutionEnabled = false;
          NSAutomaticPeriodSubstitutionEnabled = false;
          NSAutomaticQuoteSubstitutionEnabled = false;
          NSAutomaticSpellingCorrectionEnabled = false;
          NSNavPanelExpandedStateForSaveMode = true;
          NSNavPanelExpandedStateForSaveMode2 = true;
        };
      };

      keyboard = {
        enableKeyMapping = true;
        remapCapsLockToEscape = true;
      };
    };

    system.stateVersion = 6;
  };
}
