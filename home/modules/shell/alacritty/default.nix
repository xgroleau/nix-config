{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.shell.alacritty;
in
{
  options.modules.shell.alacritty = {
    enable = lib.mkEnableOption "Enables alacritty";
  };

  config = lib.mkIf cfg.enable {
    programs.alacritty = {
      enable = true;
      settings = {
        colors = {
          draw_bold_text_with_bright_colors = true;
        };

        env = {
          TERM = "xterm-256color";
        };
        mouse = {
          hide_when_typing = false;
        };

        scrolling = {
          history = 10000;
          multiplier = 3;
        };
        terminal.shell = lib.mkIf config.modules.shell.zellij.enable {
          args = [
            "attach"
            "--create"
            "default"
          ];
          program = "zellij";
        };

        window = if pkgs.stdenv.isDarwin then { option_as_alt = "OnlyLeft"; } else { };
      };
    };

    home.packages = with pkgs; [ nerd-fonts.fira-code ];
  };
}
