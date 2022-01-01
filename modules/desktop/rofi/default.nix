{ config, lib, pkgs, ... }:

{

  home.packages = with pkgs; [ fira-code ];
  xdg.configFile.rofi.source = ./rofi;

  programs.rofi = {
    enable = true;
    font = "FiraCode NF 12";
    theme = "slate";
    plugins = [
      pkgs.rofi-emoji
      pkgs.rofi-calc
    ]; # TODO: migrate i3 scripts to rofi plugins

    extraConfig = {
      modi = "drun";
      show-icons = true;
      sort = true;
      matching = "fuzzy";
      # display-drun = "Exec";
      # display-calc = "Calc";
      # display-window = "Window";
    };
  };
  
}
