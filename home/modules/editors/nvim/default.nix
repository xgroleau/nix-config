{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.editors.nvim;
in
{

  options.modules.editors.nvim = {
    enable = lib.mkEnableOption "Enables neovim with my config";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [ helix ];
    programs.neovim = {
      enable = true;
      vimAlias = true;
      vimdiffAlias = true;
    };
  };
}
