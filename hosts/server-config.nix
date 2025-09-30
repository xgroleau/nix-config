{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  keys = import ../secrets/ssh-keys.nix;
in
{

  config = {

    nix = {
      settings.trusted-users = [ "@builder" ];
    };

    users = {
      users = {
        root = {
          openssh.authorizedKeys.keys = [ keys.deployer.ghAction ];
        };

        builder = {
          isSystemUser = true;
          createHome = false;
          uid = 500;
          openssh.authorizedKeys.keys = [ keys.users.builder ];
          useDefaultShell = true;
          group = "builder";
        };
      };

      groups.builder = {
        name = "builder";
      };
    };

    systemd.extraConfig = "DefaultLimitNOFILE=32768";
  };
}
