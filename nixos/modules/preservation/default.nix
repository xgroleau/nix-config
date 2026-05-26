{
  config,
  lib,
  ...
}:

{
  config = lib.mkIf config.preservation.enable {
    boot.initrd.systemd.enable = true;

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

    age.identityPaths = [ "/persist/etc/ssh/ssh_host_ed25519_key" ];

    services.userborn = {
      enable = true;
      passwordFilesLocation = "/persist/etc";
    };

    systemd.suppressedSystemUnits = [ "systemd-machine-id-commit.service" ];

    # Keep journald persistent
    services.journald.storage = "persistent";

    systemd.tmpfiles.settings."01-var-lib-private"."/var/lib/private".d = {
      user = "root";
      group = "root";
      mode = "0700";
    };

    preservation.preserveAt = {
      "/persist" = {
        files = [
          {
            file = "/etc/machine-id";
            inInitrd = true;
          }
        ];

        directories = [
          "/var/lib/nixos"
        ];
      };

      "/state" = {
        directories = [
          "/var/lib/systemd"
          "/var/log"
          "/var/spool"
        ];
      };
    };
  };
}
