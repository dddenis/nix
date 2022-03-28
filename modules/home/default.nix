{ config, lib, ... }:

let cfg = config.home;

in {
  options.home = {
    enable' = lib.mkEnableOption "home";

    devPath = lib.mkOption {
      type = lib.types.path;
      readOnly = true;
    };

    configPath = lib.mkOption {
      type = lib.types.path;
      readOnly = true;
    };

    bookmarks = lib.mkOption {
      type = with lib.types; attrsOf path;
      default = { };
    };
  };

  config = lib.mkIf cfg.enable' {
    home = rec {
      devPath = config.user.home + "/dev";
      configPath = devPath + "/dddenis/nix";
      bookmarks = { nix = configPath; };
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
