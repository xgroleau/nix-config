{ config, lib, pkgs, ... }:

{
  imports = [ ./base-config.nix ];

  config = {
    programs.ssh.startAgent = true;

    # flatpak
    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
        xdg-desktop-portal-kde
        xdg-desktop-portal-wlr
      ];
      config.common.default = "*";
    };
    services = {
      flatpak.enable = true;
      passSecretService.enable = true;
      udev = {
        enable = true;
        packages = with pkgs; [
          # For embedded
          stlink
          qmk-udev-rules
          openocd
          libsigrok
        ];

        extraRules = ''
          # Udev rules for nrfconnect
          # https://github.com/NordicSemiconductor/nrf-udev/blob/dcd4097b4c4c00f1103f94cb8d2faba6437d8101/nrf-udev_1.0.1-all/lib/udev/rules.d/71-nrf.rules
          ACTION!="add", SUBSYSTEM!="usb_device", GOTO="nrf_rules_end"
          SUBSYSTEM=="usb", ATTRS{idVendor}=="1915", MODE="0666"
          KERNEL=="ttyACM[0-9]*", SUBSYSTEM=="tty", SUBSYSTEMS=="usb", ATTRS{idVendor}=="1915", MODE="0666", ENV{NRF_CDC_ACM}="1"
          LABEL="nrf_rules_end"
        '';
      };
      udisks2.enable = true;
    };
    # Allows the use of app image directly
    boot.binfmt.registrations.appimage = {
      wrapInterpreterInShell = false;
      interpreter = "${pkgs.appimage-run}/bin/appimage-run";
      recognitionType = "magic";
      offset = 0;
      mask = "\\xff\\xff\\xff\\xff\\x00\\x00\\x00\\x00\\xff\\xff\\xff";
      magicOrExtension = "\\x7fELF....AI\\x02";
    };
  };

}
