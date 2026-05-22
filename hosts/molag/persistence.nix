{
  config,
  lib,
  pkgs,
  ...
}:
{
  age.identityPaths = [ "/persist/etc/ssh/ssh_host_ed25519_key" ];
  services.openssh.hostKeys = [
    {
      type = "ed25519";
      path = "/persist/etc/ssh/ssh_host_ed25519_key";
    }
    {
      type = "rsa";
      bits = 4096;
      path = "/persist/etc/ssh/ssh_host_rsa_key";
    }
  ];

  services.userborn = {
    enable = true;
    passwordFilesLocation = "/persist/etc";
  };

  preservation = {
    enable = true;
    preserveAt."/persist" = {
      files = [
        {
          file = "/etc/machine-id";
          inInitrd = true;
        }
        { file = "/etc/adjtime"; }
      ];

      directories = [
        "/var/lib/nixos" # users, groups, locale bookkeeping
      ];
    };

    preserveAt."/state" = {
      directories = [
        "/var/lib/systemd"
        "/var/log"
        "/var/spool"
      ];
    };
  };

  systemd.suppressedSystemUnits = [ "systemd-machine-id-commit.service" ];

  systemd.services.bcachefs-snapshot-persist = {
    description = "Snapshot /persist on bcachefs";
    serviceConfig.Type = "oneshot";
    path = [
      pkgs.bcachefs-tools
      pkgs.coreutils
      pkgs.findutils
    ];
    script = ''
      set -euo pipefail
      ts=$(date +%Y%m%d-%H%M)
      snapdir=/persist/.snapshots
      mkdir -p "$snapdir"
      bcachefs subvolume snapshot -r /persist "$snapdir/persist-$ts"
      find "$snapdir" -maxdepth 1 -name 'persist-*' -mtime +7 \
        -exec bcachefs subvolume delete {} \;
    '';
  };
  systemd.timers.bcachefs-snapshot-persist = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
      RandomizedDelaySec = "5min";
    };
  };

  systemd.services.bcachefs-snapshot-state = {
    description = "Snapshot /state on bcachefs";
    serviceConfig.Type = "oneshot";
    path = [
      pkgs.bcachefs-tools
      pkgs.coreutils
      pkgs.findutils
    ];
    script = ''
      set -euo pipefail
      ts=$(date +%Y%m%d)
      snapdir=/state/.snapshots
      mkdir -p "$snapdir"
      bcachefs subvolume snapshot -r /state "$snapdir/state-$ts"
      find "$snapdir" -maxdepth 1 -name 'state-*' -mtime +3 \
        -exec bcachefs subvolume delete {} \;
    '';
  };
  systemd.timers.bcachefs-snapshot-state = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "15min";
    };
  };
}
