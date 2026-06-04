{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.dev.python;
in
{

  options.modules.dev.python = with lib.types; {
    enable = lib.mkEnableOption "Enables python development tools";
    package = lib.mkOption {
      type = types.package;
      default = pkgs.python3;
    };

    pythonPackages = lib.mkOption {
      type = types.attrs;
      default = pkgs.python3Packages;
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      poetry
      rye
      cfg.package
      cfg.pythonPackages.pip
      cfg.pythonPackages.black
      cfg.pythonPackages.setuptools
      cfg.pythonPackages.pylint
      #TODO: pipx 1.8.0 tests fail on 26.05 (packaging lib normalizes `name @ url` differently)
      (cfg.pythonPackages.pipx.overridePythonAttrs (_: {
        doCheck = false;
      }))
    ];
    home.sessionVariables = {
      IPYTHONDIR = "${config.xdg.configHome}/ipython";
      PIP_CONFIG_FILE = "${config.xdg.configHome}/pip/pip.conf";
      PIP_LOG_FILE = "${config.xdg.dataHome}/pip/log";
      PYLINTHOME = "${config.xdg.dataHome}/pylint";
      PYLINTRC = "${config.xdg.configHome}/pylint/pylintrc";
      PYTHONSTARTUP = "${config.xdg.configHome}/python/pythonrc";
      PYTHON_EGG_CACHE = "${config.xdg.cacheHome}/python-eggs";
      JUPYTER_CONFIG_DIR = "${config.xdg.configHome}/jupyter";
    };
  };
}
