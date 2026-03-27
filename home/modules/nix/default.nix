{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.nix;
in
{

  options.modules.nix = {
    caches = lib.mkEnableOption "Enable common caches";
    builders = lib.mkEnableOption "Enable remote builders";
  };

  config = lib.mkIf (cfg.caches || cfg.builders) {
    nix.package = lib.mkDefault pkgs.nix;

    nix.settings = lib.mkMerge [
      (lib.mkIf cfg.caches {
        substituters = [
          "https://cache.nixos.org/?priority=40"
          "https://nix-community.cachix.org?priority=41"
          "https://numtide.cachix.org?priority=42"
          "http://sheogorath:15000/xgroleau?priority=43"
        ];
        trusted-public-keys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
          "xgroleau:+u4lhV57NLS42SO5JWIURSLg2TaIbWUPe5dYXJojfRA="
        ];
        netrc-file = "${config.xdg.configHome}/nix/netrc";
      })

      (lib.mkIf cfg.builders {
        builders = lib.concatStrings [
          "ssh-ng://builder@sheogorath x86_64-linux - 1 2 nixos-test,benchmark,big-parallel,kvm - -;"
          "ssh-ng://builder@jyggalag aarch64-linux - 1 2 - - -"
        ];
      })

    ];
  };
}
