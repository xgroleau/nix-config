{
  config,
  lib,
  ...
}:

let
  cfg = config.modules.ollama;
in
{

  options.modules.ollama = with lib.types; {
    enable = lib.mkEnableOption "Ollama, an ai gpt, you know what it is";

    port = lib.mkOption {
      type = types.port;
      default = 11434;
      description = "The port to use";
    };

    dataDir = lib.mkOption {
      type = types.str;
      default = "/var/lib/ollama";
      description = "Path to where the data will be stored";
    };
  };

  config = lib.mkIf cfg.enable {
    users.deterministicIds.ollama = {
      uid = 964;
      gid = 964;
    };

    services.ollama = {
      enable = true;
      port = cfg.port;
      host = "[::]";
      home = cfg.dataDir;
      loadModels = [ "llama3.2" ];
      user = "ollama";
      group = "ollama";
    };

    # nixpkgs uses DynamicUser=true + StateDirectory=ollama, so actual
    # storage lives at /var/lib/private/ollama (with /var/lib/ollama a
    # symlink). Persist the real path — bind-mounting /var/lib/ollama
    # itself races with systemd's symlink setup and breaks boot.
    preservation.preserveAt."/persist".directories = [
      {
        directory = "/var/lib/private/ollama";
        user = config.services.ollama.user;
        group = config.services.ollama.group;
        mode = "0700";
      }
    ];
  };
}
