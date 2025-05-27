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
    xdg.configFile.zsh.source = ./config;
    programs.zsh = {
      enable = true;
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
