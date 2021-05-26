{ config, lib, ... }:

let cfg = config.home;

in {
  options.home = {
    enable' = lib.mkEnableOption "Home";

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
      devPath = config.home.homeDirectory + "/dev";
      configPath = devPath + "/dddenis/nix";
      bookmarks = { nix = configPath; };
    };

    programs.home-manager.enable = true;

    xdg.enable = true;
  };
}

