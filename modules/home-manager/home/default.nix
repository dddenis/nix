{ config, lib, outputs, ... }:

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
    home.stateVersion = outputs.stateVersion;

    xdg.enable = true;
  };
}
