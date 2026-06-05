{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.shell.zsh;
  pythonCfg = config.modules.dev.python;
in
{

  options.modules.shell.zsh = {
    enable = lib.mkEnableOption "Enables zsh";
  };

  config = lib.mkIf cfg.enable {
    # Single whole-dir symlink: the recursive per-file links pointed into a separate
    # hm_config store path that automatic GC reaped, breaking zsh. dotDir stays in
    # $HOME (below) so it doesn't collide with this symlink.
    xdg.configFile.zsh.source = ./config;
    programs.zsh = {
      enable = true;
      dotDir = config.home.homeDirectory;
      envExtra = "source ${config.xdg.configHome}/zsh/zshenv";
      initContent = "source ${config.xdg.configHome}/zsh/zshrc";
      history = {
        expireDuplicatesFirst = true;
        ignoreAllDups = true;
      };
    };

    home = {
      packages = with pkgs; [
        nix-zsh-completions
        git
        pythonCfg.package
      ];
      sessionPath = [
        "${config.home.homeDirectory}/.local/bin"
        "${config.home.homeDirectory}/bin"
      ];
    };
  };
}
