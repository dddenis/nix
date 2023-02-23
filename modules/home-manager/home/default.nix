{ config, lib, osConfig, ... }:

let cfg = config.home;

in
{
  options.home = {
    configPath = lib.mkOption {
      type = lib.types.path;
      readOnly = true;
      default = "${config.home.homeDirectory}/.nix";
    };

    bookmarks = lib.mkOption {
      type = with lib.types; attrsOf path;
      default = { };
    };
  };

  config = {
    home.bookmarks = { nix = cfg.configPath; };
    home.stateVersion = osConfig.system.stateVersion;

    xdg = {
      enable = true;
      mimeApps.enable = true;
      configFile."mimeapps.list".force = true;
    };
  };
}
