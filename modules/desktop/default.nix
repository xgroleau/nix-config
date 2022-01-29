{ config, lib, pkgs, ... }:

{
  fonts.fontconfig.enable = true;
  xdg.enable = true;
  xsession.enable = true;

  home.packages = with pkgs;
    [
      # for font
      (nerdfonts.override { fonts = ["FiraCode"]; })
    ];
  imports = [ ./temp ];
}
