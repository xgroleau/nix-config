{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.dev.cc;
in
{

  options.modules.dev.cc = {
    enable = lib.mkEnableOption "Enables C lang development tools";
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      with pkgs;
      [
        clang
        clang-tools
        cmake
        gnumake
      ]
      ++ lib.optionals stdenv.isLinux [ gdb ];
  };
}
