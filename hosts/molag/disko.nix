{ lib, ... }: {
  disko.devices = {
    # Root is tmpfs — wiped every boot. The 16G install-time size is enough
    # headroom for nixos-anywhere's temporary files; the actual running
    # tmpfs at / can be smaller.
    nodev."/" = {
      fsType = "tmpfs";
      mountOptions = [
        "defaults"
        "size=16G"
        "mode=755"
      ];
    };

    disk.main = {
      type = "disk";
      device = "/dev/disk/by-id/virtio-vdisk1";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };

          main = {
            size = "100%";
            content = {
              type = "bcachefs";
              filesystem = "main";
              label = "main";
            };
          };
        };
      };
    };

    bcachefs_filesystems.main = {
      type = "bcachefs_filesystem";
      mountpoint = "/bcachefs"; # also mount the FS root for the bind mounts below
      extraFormatArgs = [ "--compression=zstd" ];

      # Subvolumes get mountpoints here so disko mounts them at install time
      # (/mnt/nix, /mnt/persist, etc. land on the real bcachefs with 249GB).
      # We override the running system's fileSystems entries below to use
      # bind mounts instead, which avoids the parallel-mount EBUSY race that
      # bcachefs hits when systemd-initrd mounts the same device multiple
      # times in parallel.
      subvolumes = {
        "nix" = {
          mountpoint = "/nix";
          mountOptions = [ "noatime" ];
        };
        "persist" = {
          mountpoint = "/persist";
          mountOptions = [ "noatime" ];
        };
        "state" = {
          mountpoint = "/state";
          mountOptions = [ "noatime" ];
        };
        "backups" = {
          mountpoint = "/backups";
          mountOptions = [ "noatime" ];
        };
      };
    };
  };

  # Running-system mount strategy: replace disko's subvolume mounts with
  # bind mounts off a single /bcachefs mount. Disko's install-time bash
  # script is unaffected by this — it has its own mount logic.
  fileSystems = {
    "/bcachefs".neededForBoot = true;

    "/nix" = lib.mkForce {
      device = "/bcachefs/nix";
      fsType = "none";
      options = [ "bind" ];
      depends = [ "/bcachefs" ];
    };
    "/persist" = lib.mkForce {
      device = "/bcachefs/persist";
      fsType = "none";
      options = [ "bind" ];
      depends = [ "/bcachefs" ];
      neededForBoot = true;
    };
    "/state" = lib.mkForce {
      device = "/bcachefs/state";
      fsType = "none";
      options = [ "bind" ];
      depends = [ "/bcachefs" ];
      neededForBoot = true;
    };
    "/backups" = lib.mkForce {
      device = "/bcachefs/backups";
      fsType = "none";
      options = [ "bind" ];
      depends = [ "/bcachefs" ];
    };
  };
}
