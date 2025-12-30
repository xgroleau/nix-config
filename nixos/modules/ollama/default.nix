{
  config,
  lib,
  pkgs,
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

  config =
    let
      homePath = "${cfg.dataDir}/home";
      modelsPath = "${cfg.dataDir}/models";
    in
    lib.mkIf cfg.enable {
      services.ollama = {
        enable = true;
        port = cfg.port;
        host = "[::]";
        home = cfg.dataDir;
        loadModels = [ "llama3.2" ];
        user = "ollama";
        group = "ollama";
      };

      systemd.tmpfiles.settings.ollama = {
        "${cfg.dataDir}" = {
          d = {
            mode = "0744";
            user = config.services.ollama.user;
            group = config.services.ollama.group;
          };
        };
      };
    };
}
