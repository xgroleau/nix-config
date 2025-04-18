{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./ark-survival-ascended
    ./attic
    ./authentik
    ./caddy
    ./docker
    ./duckdns
    ./home
    ./immich
    ./kdeconnect
    ./firefly-iii
    ./ollama
    ./mealie
    ./media-server
    ./minecraft
    ./monitoring
    ./msmtp
    ./opencloud
    ./palworld
    ./ssh
    ./tailscale
    ./valheim
    ./xserver
  ];
}
