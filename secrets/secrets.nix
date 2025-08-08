let
  keys = import ./ssh-keys.nix;
in
with keys;
{
  "alertmanager-env.age".publicKeys = [
    users.xgroleau
    machines.jyggalag
  ];
  "attic-env.age".publicKeys = [
    users.xgroleau
    machines.sheogorath
  ];
  "authentik-env.age".publicKeys = [
    users.xgroleau
    machines.sheogorath
  ];
  "cloudflare-xgroleau.age".publicKeys = [
    users.xgroleau
    machines.sheogorath
  ];
  "firefly-appkey.age".publicKeys = [
    users.xgroleau
    machines.sheogorath
  ];
  "firefly-importer-token.age".publicKeys = [
    users.xgroleau
    machines.sheogorath
  ];
  "duckdns-token.age".publicKeys = [
    users.xgroleau
    machines.jyggalag
  ];
  "gmx-pass.age".publicKeys = [
    users.xgroleau
    machines.sheogorath
  ];
  "immich-env.age".publicKeys = [
    users.xgroleau
    machines.sheogorath
  ];
  "mealie-env.age".publicKeys = [
    users.xgroleau
    machines.sheogorath
  ];
  "opencloud-env.age".publicKeys = [
    users.xgroleau
    machines.sheogorath
  ];
  "paperless-ngx-env.age".publicKeys = [
    users.xgroleau
    machines.sheogorath
  ];
  "pia-ovpn.age".publicKeys = [
    users.xgroleau
    machines.sheogorath
  ];
}
