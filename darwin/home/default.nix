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
            stateVersion = "25.05";
            homeDirectory = "/Users/${cfg.username}";

            activation = {
              # This should be removed once
              # https://github.com/nix-community/home-manager/issues/1341 is closed.
              aliasHomeManagerApplications = inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                app_folder="/Users/${cfg.username}/Applications/Home Manager Trampolines"
                rm -rf "$app_folder"
                mkdir -p "$app_folder"
                find "$genProfilePath/home-path/Applications" -type l -print | while read -r app; do
                    app_target="$app_folder/$(basename "$app")"
                    real_app="$(readlink "$app")"
                    echo "mkalias \"$real_app\" \"$app_target\"" >&2
                    $DRY_RUN_CMD ${pkgs.mkalias}/bin/mkalias "$real_app" "$app_target"
                done
              '';
            };
          };
        };
      };
    };
  };
}
