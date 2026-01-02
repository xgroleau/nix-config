{
  config,
  options,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.dev.common;
in
{

  options.modules.dev.common = with lib.types; {
    enable = lib.mkEnableOption "Enable common development settings and tools";

    gitUser = lib.mkOption {
      type = types.str;
      default = "xgroleau";
    };

    gitEmail = lib.mkOption {
      type = types.str;
      default = "xavgroleau@gmail.com";
    };
  };

  config = lib.mkIf cfg.enable {

    programs = {
      git = {
        enable = true;
        settings.user = {
          name = cfg.gitUser;
          email = cfg.gitEmail;
        };
        lfs.enable = true;
      };

      direnv = {
        enable = true;
        nix-direnv.enable = true;
      };
      direnv-instant.enable = true;

      zoxide = {
        enable = true;
        enableZshIntegration = true;
      };

      eza = {
        enable = true;
        enableZshIntegration = true;
      };

      fzf = {
        enable = true;
        enableZshIntegration = true;
      };
    };
    home = {
      packages = with pkgs; [
        btop
        bat
        comma
        dust
        fd
        gh
        jujutsu
        jq
        killall
        lazyjj
        pre-commit
        ranger
        ripgrep
        tldr
      ];
    };
  };
}
