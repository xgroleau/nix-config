{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.desktop;
in
{
  config = lib.mkIf (cfg.active == "i3") {
    fonts.fontconfig.enable = true;

    home.packages = with pkgs; [
      arandr
      brightnessctl
      flameshot
      flashfocus
      nerd-fonts.fira-code
      xclip
      (rofi.override {
        plugins = [
          rofi-emoji
          rofi-calc
        ];
      })
      rofi-power-menu
      playerctl
      pulseaudio

      # KDE apps
      libsForQt5.ark
      libsForQt5.dolphin
      libsForQt5.okular
      libsForQt5.breeze-icons
    ];

    home.sessionVariables = {
      XDG_CURRENT_DESKTOP = "i3";
    };

    programs.autorandr = {
      enable = true;
      hooks.postswitch = {
        polybar = "systemctl --user restart polybar";
        background = "systemctl --user restart random-background";
      };
    };

    # Until https://github.com/NixOS/nixpkgs/pull/417193  land
    programs.i3lock.enable = true;

    services = {

      betterlockscreen = {
        enable = true;
        inactiveInterval = 45;
        arguments = [ "-u ${./config/wallpapers} " ];
      };

      dunst = {
        enable = true;
        configFile = ./config/dunst/dunstrc;
      };

      gnome-keyring.enable = true;
      network-manager-applet.enable = true;

      kdeconnect = {
        enable = true;
        indicator = true;
      };

      picom = {
        enable = true;
        wintypes = {
          tooltip = {
            fade = true;
            shadow = true;
            opacity = 0.95;
            focus = true;
            full-shadow = false;
          };
          dock = {
            shadow = false;
            opacity = 0.8;
          };
          dnd = {
            shadow = false;
          };
          menu = {
            shadow = false;
          };
          popup_menu = {
            opacity = 0.95;
          };
          dropdown_menu = {
            opacity = 0.8;
          };
        };
        settings = {
          blur = true;
          xinerama-shadow-crop = true;
        };
        inactiveOpacity = 0.95;
        shadow = true;
        shadowOffsets = [
          (-5)
          (-5)
        ];
        shadowOpacity = 1.0;
        shadowExclude = [
          "class_g = 'i3-frame'"
          "name = 'noshadow'"
        ];
        vSync = true;
      };

      polybar = {
        enable = true;
        package = pkgs.polybarFull;
        config = ./config/polybar/config.ini;
        script = ''
          for m in $(polybar --list-monitors | ${pkgs.coreutils}/bin/cut -d":" -f1); do
            MONITOR=$m polybar --reload main &
          done'';
      };

      random-background = {
        enable = true;
        imageDirectory = "${./config/wallpapers}";
        interval = "2h";
      };

      redshift = {
        enable = true;
        provider = "manual";
        latitude = 40.74;
        longitude = -74.0;
        temperature = {
          day = 5000;
          night = 3800;
        };
        settings = {
          redshift = {
            fade = true;
            adjustment-method = "randr";
            gamma-day = "0.95:0.95:0.95";
            gamma-night = "0.95:0.95:0.95";
          };
        };
      };

      unclutter.enable = true;
      udiskie.enable = true;
    };

    xdg = {
      enable = true;
      configFile = {
        autorandr = {
          recursive = true;
          source = ./config/autorandr;
        };
        rofi.source = ./config/rofi;
      };
    };

    xsession = {
      enable = true;
      windowManager.i3 =
        let
          mod = "Mod4";
          alt = "Mod1";
        in
        {
          enable = true;
          config = {
            modifier = mod;

            bars = [
              {
                id = "bar-tray";
                position = "bottom";
                workspaceButtons = false;
                mode = "hide";
                hiddenState = "hide";
                command = "i3bar --transparency";
                trayOutput = "primary";
                trayPadding = 0;

                colors = {
                  background = "#00000001";
                };

                extraConfig = ''
                  modifier ${mod}+${alt}
                '';
              }
            ];

            keybindings = lib.mkOptionDefault {
              # Window management

              # move focused container to workspace
              "${mod}+Shift+1" = "move container to workspace number 1; workspace number 1";
              "${mod}+Shift+2" = "move container to workspace number 2; workspace number 2";
              "${mod}+Shift+3" = "move container to workspace number 3; workspace number 3";
              "${mod}+Shift+4" = "move container to workspace number 4; workspace number 4";
              "${mod}+Shift+5" = "move container to workspace number 5; workspace number 5";
              "${mod}+Shift+6" = "move container to workspace number 6; workspace number 6";
              "${mod}+Shift+7" = "move container to workspace number 7; workspace number 7";
              "${mod}+Shift+8" = "move container to workspace number 8; workspace number 8";
              "${mod}+Shift+9" = "move container to workspace number 9; workspace number 9";
              "${mod}+Shift+0" = "move container to workspace number 10; workspace number 10";

              "${mod}+h" = "focus left";
              "${mod}+j" = "focus down";
              "${mod}+k" = "focus up";
              "${mod}+l" = "focus right";

              "${mod}+Shift+h" = "move left";
              "${mod}+Shift+j" = "move down";
              "${mod}+Shift+k" = "move up";
              "${mod}+Shift+l" = "move right";

              "${mod}+Return" = "exec alacritty";
              "${mod}+space" = "exec --no-startup-id rofi -show drun -modi drun";
              "${mod}+w" = "exec --no-startup-id rofi -show window -modi window";
              "${mod}+x" = "exec --no-startup-id rofi -show combi -modi combi";
              "${mod}+c" =
                "exec --no-startup-id rofi -show calc -modi calc -no-show-match -no-sort -calc-command 'echo {result}' | xclip -selection clipboard";
              "${mod}+p" = "exec --no-startup-id rofi -show p:rofi-power-menu";
              "${mod}+semicolon" =
                "exec --no-startup-id rofi -show emoji -modi emoji -emoji-format '{emoji}: {name}'";
              "${mod}+Shift+s" = "exec --no-startup-id flameshot gui";
              "${mod}+d" = "exec --no-startup-id emacsclient --eval '(emacs-everywhere)'";

              # Notification control
              "${alt}+space" = "exec dunstctl close";
              "${alt}+Shift+space" = "exec dunstctl close-all";
              "${alt}+period" = "exec dunstctl history";
              "${alt}+Shift+period" = "exec dunstctl context";
              "${mod}+${alt}+r" = "exec systemctl --user restart polybar.service";

              # Volume and Media Control
              "XF86AudioRaiseVolume" = "exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ +10%";
              "XF86AudioLowerVolume" = "exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ -10%";
              "XF86AudioMute" = "exec --no-startup-id pactl set-sink-mute @DEFAULT_SINK@ toggle";
              "XF86AudioMicMute" = "exec --no-startup-id pactl set-source-mute @DEFAULT_SOURCE@ toggle";
              "XF86MonBrightnessUp" = "exec brightnessctl set +10%";
              "XF86MonBrightnessDown" = "exec brightnessctl set 10%-";
              "XF86AudioPlay" = "exec playerctl play-pause";
              "XF86AudioNext" = "exec playerctl next";
              "XF86AudioPrev" = "exec playerctl previous";

              # Window Management
              "${mod}+f" = "fullscreen toggle";
              "${mod}+t" = "layout tabbed";
              "${mod}+Shift+f" = "floating toggle";
              "${mod}+Shift+d" = "focus mode_toggle";
            };

            # Window Rules for Specific Applications
            window = {
              border = 0;
              titlebar = false;

              commands = [
                {
                  criteria = {
                    title = "Microsoft Teams Notification";
                  };
                  command = "floating enable";
                }
                {
                  criteria = {
                    class = "plasmashell";
                    window_type = "notification";
                  };
                  command = "floating enable, border none, move right 700px, move down 450px";
                }
                {
                  criteria = {
                    title = "Desktop — Plasma";
                  };
                  command = "kill; floating enable; border none";
                }
                {
                  criteria = {
                    class = "Steam";
                  };
                  command = "floating enable";
                }
                {
                  criteria = {
                    class = "Steam";
                    title = "^Steam$";
                  };
                  command = "floating disable";
                }
              ];
            };
          };
          extraConfig = ''
            exec_always --no-startup-id autorandr -c
            exec_always --no-startup-id systemctl --user restart polybar
            exec_always --no-startup-id flashfocus --time 100
          '';
        };
    };
  };
}
