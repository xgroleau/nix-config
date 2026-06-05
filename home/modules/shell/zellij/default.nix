{
  config,
  lib,
  ...
}:

let
  cfg = config.modules.shell.zellij;
in
{
  options.modules.shell.zellij = {
    enable = lib.mkEnableOption "Enables zellij";
  };

  config = lib.mkIf cfg.enable {
    programs.zellij = {
      enable = true;
      settings = {
        on_force_close = "detach";
        pane_frames = false;
      };
    };
  };
}
