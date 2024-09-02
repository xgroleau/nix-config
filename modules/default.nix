{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./ark-survival-ascended
    ./authentik
    ./caddy
    ./docker
    ./duckdns
    ./home
    ./immich
    ./kdeconnect
    ./firefly-iii
    ./mealie
    ./media-server
    ./monitoring
    ./msmtp
    ./ocis
    ./palworld
    ./ssh
    ./tailscale
    ./valheim
    ./xserver
  ];
}
