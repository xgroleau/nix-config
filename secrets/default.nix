{
  options,
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.secrets;
  keys = import ./ssh-keys.nix;
  ageSecrets = import ./secrets.nix;

  # Get key or invalid key if doesn't exist in the ssh-keys.nix
  machineKey = keys.machines."${config.networking.hostName}" or "INVALID SSH KEY";

  # Filter for the secrets to only have the ones that have the host key
  filterSecrets =
    name: att:
    let
      keyName = builtins.baseNameOf att.file;
    in
    builtins.elem machineKey ageSecrets."${keyName}".publicKeys;

  # attrset of the secrets
  secrets = {
    alertmanagerEnv.file = ./alertmanager-env.age;
    atticEnv.file = ./attic-env.age;
    authentikEnv.file = ./authentik-env.age;
    gluetunEnv.file = ./gluetun-env.age;
    cloudflareXgroleau.file = ./cloudflare-xgroleau.age;
    duckdnsToken.file = ./duckdns-token.age;
    fireflyAppKey.file = ./firefly-appkey.age;
    fireflyImporterToken.file = ./firefly-importer-token.age;
    gmxPass.file = ./gmx-pass.age;
    immichEnv.file = ./immich-env.age;
    mealieEnv.file = ./mealie-env.age;
    minifluxEnv.file = ./miniflux-env.age;
    ntfyEnv.file = ./ntfy-env.age;
    opencloudEnv.file = ./opencloud-env.age;
    paperlessNgxEnv.file = ./paperless-ngx-env.age;
    stalwartEnv.file = ./stalwart-env.age;
    vaultwardenEnv.file = ./vaultwarden-env.age;
  };

  # Only secrets that have the machine ssh key in them
  filteredSecrets = lib.attrsets.filterAttrs filterSecrets secrets;
in
{

  options.modules.secrets = {
    enable = lib.mkEnableOption "Enables secrets management";
  };

  config = lib.mkIf cfg.enable {
    age = {
      secrets = filteredSecrets;
    };
  };
}
