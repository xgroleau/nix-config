{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.darwin.aerospace;
in
{

  options.modules.darwin.aerospace = with lib.types; {
    enable = lib.mkEnableOption "Enables the aerospace and configures it, requires the home and homebrew modules";
  };

  config = lib.mkIf cfg.enable {
    modules.darwin.home.extraHomeModules = [
      {
        xdg.configFile.aerospace = {
          source = ./aerospace;
          recursive = true;
        };

        xdg.configFile.sketchybar = {
          source = ./sketchybar;
          recursive = true;
        };

        home.packages = with pkgs; [ nerd-fonts.fira-code ];
      }
    ];
    system.defaults = {
      spaces.spans-displays = false;
      NSGlobalDomain = {
        _HIHideMenuBar = true;
        NSWindowShouldDragOnGesture = true;
      };
    };

    homebrew = {
      taps = [
        # sketchybar
        "FelixKratz/formulae"

        # aerospace
        "nikitabobko/tap"
      ];
      brews = [
        "borders"
        "sketchybar"
      ];
      casks = [ "aerospace" ];
    };
  };
}
