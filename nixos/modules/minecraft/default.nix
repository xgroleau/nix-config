{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.minecraft;
in

{

  options.modules.minecraft = with lib.types; {
    enable = lib.mkEnableOption "Minecraft";

    openFirewall = lib.mkEnableOption "Open the required ports in the firewall";

    port = lib.mkOption {
      type = types.port;
      default = 25565;
      description = "the port to use";
    };

    name = lib.mkOption {
      type = lib.types.str;
      default = "Minecraft";
      description = "Name for the server";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/minecraft";
      description = "Where on disk to store your minecraft directory";
    };

    type = lib.mkOption {
      type = lib.types.str;
      default = "FABRIC";
      description = "Type of minecraft server";
    };

    version = lib.mkOption {
      type = lib.types.str;
      default = "LATEST";
      description = "Version of the minecraft server";
    };

    packwizPackUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      example = "https://raw.githubusercontent.com/USER/REPO/tags/x.y.z/pack.toml";
      description = "PackWiz url, need to point to a pack.toml file";
    };

  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers = {
      containers."minecraft-${cfg.name}" = {
        autoStart = true;
        image = "itzg/minecraft-server";
        ports = [ "${toString cfg.port}:25565" ];
        environment = {
          EULA = "TRUE";
          ONLINE_MODE = "FALSE";
          MOTD = "${cfg.name} server :)";
          SERVER_NAME = cfg.name;
          TYPE = cfg.type;
          VERSION = cfg.version;
          PACKWIZ_URL = cfg.packwizPackUrl;
        };

        volumes = [
          "${cfg.dataDir}:/data"
        ];
      };

    };

    networking.firewall = lib.mkIf cfg.openFirewall { allowedTCPPorts = [ cfg.port ]; };

    # Create the folder if it doesn't exist
    systemd.tmpfiles.settings."mineraft-${cfg.name}" = {
      "${cfg.dataDir}" = {
        d = {
          user = "root";
          group = "root";
          mode = "777";
        };
      };
    };
  };

}
