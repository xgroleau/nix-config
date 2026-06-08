_: {
  disko.devices = {
    disk.main = {
      type = "disk";

      device = "/dev/sda";
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

          swap = {
            size = "8G";
            content = {
              type = "swap";
              randomEncryption = true;
            };
          };

          zfs = {
            size = "100%";
            content = {
              type = "zfs";
              pool = "rpool";
            };
          };
        };
      };
    };

    zpool.rpool = {
      type = "zpool";
      rootFsOptions = {
        canmount = "off";
        mountpoint = "none";
        compression = "zstd";
        acltype = "posixacl";
        xattr = "sa";
        dnodesize = "auto";
        atime = "off";
        "com.sun:auto-snapshot" = "false";
      };
      options = {
        ashift = "12";
        autotrim = "on";
      };

      datasets = {
        root = {
          type = "zfs_fs";
          mountpoint = "/";
          options = {
            mountpoint = "legacy";
            canmount = "noauto";
          };
          # preservation blank
          postCreateHook = ''
            zfs list -t snapshot -H -o name | grep -E '^rpool/root@blank$' || \
              zfs snapshot rpool/root@blank
          '';
        };

        nix = {
          type = "zfs_fs";
          mountpoint = "/nix";
          options.mountpoint = "legacy";
        };

        # Non-precious state, but persisted
        state = {
          type = "zfs_fs";
          mountpoint = "/state";
          options.mountpoint = "legacy";
        };

        # Persisted state
        persist = {
          type = "zfs_fs";
          mountpoint = "/persist";
          options = {
            mountpoint = "legacy";
            "com.sun:auto-snapshot" = "true";
          };
        };

        # Pool-fill insurance https://nixos.wiki/wiki/ZFS#Reservations
        reserved = {
          type = "zfs_fs";
          options = {
            canmount = "off";
            refreservation = "4G";
          };
        };
      };
    };
  };
}
