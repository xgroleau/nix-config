{
  config,
  lib,
  inputs,
  ...
}:

let
  cfg = config.modules.home;
  profiles = import ../../../home/profiles;
in
{

  options.modules.home = with lib.types; {

    enable = lib.mkEnableOption "Enables the home manager module and profile";
    profile = lib.mkOption {
      type = nullOr str;
      default = null;
      description = ''
        The profile used for the nix-dotfiles
      '';
    };
    username = lib.mkOption {
      type = str;
      default = null;
      description = ''
        The username of the nix-dotfiles
      '';
    };
  };

  config = lib.mkIf cfg.enable {

    home-manager = {
      useUserPackages = true;
      sharedModules = [ ../../../home ];
      extraSpecialArgs = {
        inherit inputs;
      };

      users.${cfg.username} = {
        imports = [ profiles.${cfg.profile} ];
        config = {
          home.stateVersion = "26.05";
        };
      };
    };

    preservation.preserveAt."/persist".directories = [
      {
        directory = config.users.users.${cfg.username}.home;
        user = cfg.username;
        group = config.users.users.${cfg.username}.group;
        mode = "0700";
      }
    ];
  };
}
