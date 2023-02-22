{ config, lib, ... }:

let cfg = config.home;

in
{
  options.home = {
    enable' = lib.mkEnableOption "home";

    configPath = lib.mkOption {
      type = lib.types.path;
      readOnly = true;
      default = "${config.user.home}/.nix";
    };

    bookmarks = lib.mkOption {
      type = with lib.types; attrsOf path;
      default = { };
    };
  };

  config = lib.mkIf cfg.enable' {
    home = {
      bookmarks = { nix = cfg.configPath; };
    };

    # TODO
    hm.programs.home-manager.enable = true;

    hm.xdg = {
      enable = true;
      mimeApps.enable = true;
      configFile."mimeapps.list".force = true;
    };
  };
}
