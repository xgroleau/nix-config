{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  profiles = import ../../home/profiles;
  cfg = config.modules.darwin.home;
in
{

  imports = [ inputs.home-manager.darwinModules.home-manager ];

  options.modules.darwin.home = with lib.types; {
    enable = lib.mkEnableOption "Enables the home manager module and profile";
    username = lib.mkOption {
      type = str;
      default = null;
      description = ''
        The username of the user
      '';
    };
    extraHomeModules = lib.mkOption {
      type = with types; listOf attrs;
      default = [ ];
      description = ''
        Additionnal modules to add to the home configuration
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    users.users."${cfg.username}".home = "/Users/${cfg.username}";

    home-manager = {
      sharedModules = [ ../../home ];
      extraSpecialArgs = {
        inherit inputs;
      };
      users."${cfg.username}" = {
        imports = [ profiles."macos" ] ++ cfg.extraHomeModules;
        config = {
          home = {
            stateVersion = "25.11";
            homeDirectory = "/Users/${cfg.username}";
          };
        };
      };
    };
  };
}
