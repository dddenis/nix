{ config, lib, pkgs, ... }:

let
  inherit (lib) types;

  cfg = config.fonts;

in {
  options.fonts = {
    enable' = lib.mkEnableOption "fonts";

    fonts = lib.mkOption {
      type = types.listOf types.package;
      default = [ ];
    };
  };

  config = lib.mkMerge [
    { home.packages = cfg.fonts; }

    (lib.mkIf cfg.enable' { fonts.fontconfig.enable = true; })
  ];
}
