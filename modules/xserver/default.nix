{
  config,
  lib,
  pkgs,
  profiles,
  ...
}:

let
  cfg = config.modules.xserver;
in
{
  options.modules.xserver = {
    home-manager = lib.mkEnableOption "Let home-manager manage the session";
  };

  config = lib.mkIf cfg.home-manager {
    environment.systemPackages = [ pkgs.sddm-chili-theme ];
    services = {

      displayManager = {
        enable = true;
        defaultSession = "none+fake";

        # Setup login manager
        sddm = {
          enable = true;
          theme = "chili";
        };
      };

      # Use a fake session. The actual session is managed by Home Manager.
      xserver = {
        enable = true;
        displayManager = {
          session =
            let
              fakeSession = {
                manage = "window";
                name = "fake";
                start = "";
              };
            in
            [ fakeSession ];
        };
      };
    };
  };
}
