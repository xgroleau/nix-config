{
  config,
  lib,
  ...
}:
{
  preservation.enable = true;

  boot.initrd.systemd.services.rollback-root = {
    description = "Roll back rpool/root to @blank before mount";
    wantedBy = [ "initrd.target" ];
    requires = [ "zfs-import-rpool.service" ];
    after = [ "zfs-import-rpool.service" ];
    before = [ "sysroot.mount" ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe config.boot.zfs.package} rollback -r rpool/root@blank";
    };
  };

  preservation.preserveAt."/persist".files = [
    {
      file = "/etc/zfs/zpool.cache";
      inInitrd = true;
    }
  ];
}
