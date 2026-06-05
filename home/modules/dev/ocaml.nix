{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.dev.ocaml;
in
{

  options.modules.dev.ocaml = {
    enable = lib.mkEnableOption "Enables OCaml development tools";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      dune_3
      ocaml
      ocamlPackages.lsp
    ];
  };
}
