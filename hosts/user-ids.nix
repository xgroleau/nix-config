{
  # Pinned uids/gids for every user/group declared on any host.
  # Mechanism lives in `nixos/modules/users-ids/`; this file is the registry.
  #
  # Conventions:
  # - UID == GID by convention; use the `uidGid` helper
  # - System services count down from 999; human users start at 1000
  # - Once published, a uid/gid should NOT be reused. Comment retired
  #   entries so the number stays "burned".
  # - Changing a uid for an existing service requires chown'ing its
  #   persistent data on every host that holds files owned by that user.

  users.deterministicIds =
    let
      uidGid = id: {
        uid = id;
        gid = id;
      };
    in
    {
      # Human users (1000+)
      xgroleau = uidGid 1000;
      console = uidGid 1001;

      # System services / daemons (counting down from 999)
      systemd-oom = uidGid 999;
      systemd-coredump = uidGid 998;
      sshd = uidGid 997;
      nscd = uidGid 996;
      polkituser = uidGid 995;
      rtkit = uidGid 994;
      dhcpcd = uidGid 993;
      promtail = uidGid 992;
      grafana = uidGid 991;
      loki = uidGid 990;
      crowdsec = uidGid 989;
      node-exporter = uidGid 988;
      fwupd-refresh = uidGid 987;
      geoclue = uidGid 986;
      wpa_supplicant = uidGid 985;
      flatpak = uidGid 984;
      nm-iodine = uidGid 983;
      decky = uidGid 982;

      # Application / service users with persistent data
      # (DO NOT renumber these without chown'ing the relevant /var dirs)
      vaultwarden = uidGid 970;
      ntfy-sh = uidGid 969;
      jellyfin = uidGid 968;
      bazarr = uidGid 967;
      readarr = uidGid 966;
      valheim = uidGid 965;
      ollama = uidGid 964;

      # Group-only entries (the user, if any, has a hardcoded uid in nixpkgs;
      # we only pin the group here)
      builder.gid = 950;
      media.gid = 951;
      podman.gid = 952;
      plugdev.gid = 953;
      lpadmin.gid = 954;
      uinput.gid = 955;
    };
}
