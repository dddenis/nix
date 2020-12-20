{ config, lib, ... }:

let cfg = config.xdg;

in {
  options.xdg = {
    configSymlink = lib.mkOption {
      type = with lib.types; attrsOf string;
      default = { };
    };
  };

  config = lib.mkIf cfg.enable {
    home.symlink = lib.mapAttrs'
      (dest: src: lib.nameValuePair "${cfg.configHome + "/${dest}"}" src)
      cfg.configSymlink;
  };
}
