{
  config,
  lib,
  ...
}:

let
  cfg = config.modules.shell.tmux;
in
{
  options.modules.shell.tmux = {
    enable = lib.mkEnableOption "Enables tmux";
  };

  config = lib.mkIf cfg.enable {
    programs.tmux = {
      enable = true;
    };
    xdg.configFile.tmux.source = ./config;
  };
}
