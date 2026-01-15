# Some modules for common presets for profile
rec {
  minimal = _: {
    config.modules = {
      dev.common.enable = true;
      editors.nvim.enable = true;
      nix.caches = true;
      nixpkgs.enable = true;
      shell.zellij.enable = true;
      shell.zsh.enable = true;
    };
  };

  dev = _: {
    imports = [ minimal ];
    config = {
      modules = {
        editors.emacs = {
          enable = true;
          defaultEditor = true;
        };
        dev = {
          cc.enable = true;
          python.enable = true;
          rust.enable = true;
        };
        nix.builders = true;
      };
    };
  };

  macos =
    { pkgs, ... }:
    {
      imports = [ dev ];
      config = {
        modules = {
          shell.alacritty.enable = true;
          keyboards.kanata.enable = true;
        };

        home.packages = with pkgs; [
          thunderbird
        ];
      };
    };

  graphical =
    { pkgs, ... }:
    {
      imports = [ dev ];
      config = {
        modules = {
          applications.firefox.enable = true;
          applications.discord.enable = true;
          editors.vscode.enable = true;
          shell.alacritty.enable = true;
          keyboards.kanata.enable = true;
        };

        home.packages = with pkgs; [
          bitwarden-desktop
          element-desktop
          beeper
          mattermost-desktop
          slack
          spotify
          thunderbird
        ];
      };
    };

  desktop = _: {
    imports = [ graphical ];
    config = {
      modules = {
        desktop.active = "i3";
      };
    };
  };
}
