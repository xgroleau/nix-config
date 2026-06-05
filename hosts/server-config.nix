{
  pkgs,
  ...
}:

let
  keys = import ../secrets/ssh-keys.nix;
in
{

  config = {
    modules.security = {
      enable = true;
      crowdsec.enable = true;
      fail2ban.enable = true;
    };

    nix = {
      settings.trusted-users = [ "@builder" ];
    };

    users = {
      users = {
        root = {
          openssh.authorizedKeys.keys = [
            keys.deployer.ghAction
            # keys.users.xgroleau
          ];
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

    systemd.settings.Manager = {
      DefaultLimitNOFILE = 32768;
    };

    systemd.services.reboot-if-stale-kernel = {
      description = "Reboot if booted kernel/initrd differs from latest generation";
      serviceConfig.Type = "oneshot";
      script = ''
        booted=$(readlink /run/booted-system/{initrd,kernel,kernel-modules})
        built=$(readlink /run/current-system/{initrd,kernel,kernel-modules})
        if [ "$booted" != "$built" ]; then
          ${pkgs.systemd}/bin/shutdown -r +1 "Rebooting for kernel update"
        fi
      '';
    };
    systemd.timers.reboot-if-stale-kernel = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 05:30:00";
        Persistent = true;
        RandomizedDelaySec = "10min";
      };
    };
  };
}
