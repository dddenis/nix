{ config, lib, ... }:

let cfg = config.home;

in {
  options.home = {
    enable' = lib.mkEnableOption "Home";

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
      configPath = config.home.homeDirectory + "/dev/dddenis/nix";

      bookmarks = { nix = configPath; };
    };

    programs.home-manager.enable = true;

    xdg.enable = true;
  };
}

