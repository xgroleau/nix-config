{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.dev.rust;
in
{

  options.modules.dev.rust = {
    enable = lib.mkEnableOption "Enables rust development tools";
  };

  config = lib.mkIf cfg.enable {
    home = {
      packages = with pkgs; [
        bacon
        rustup
        cargo-expand
        cargo-generate
        cargo-readme
      ];

      sessionVariables = {
        RUSTUP_HOME = "${config.xdg.dataHome}/rustup";
        CARGO_HOME = "${config.xdg.dataHome}/cargo";
      };
      sessionPath = [ "${config.home.sessionVariables.CARGO_HOME}/bin" ];
    };
  };
}
