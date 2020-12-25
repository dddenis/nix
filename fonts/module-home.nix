{ config, lib, pkgs, ... }:

let cfg = config.fonts;

in {
  options.fonts = {
    enable' = lib.mkEnableOption "fonts";

    fonts = lib.mkOption {
      type = with lib.types; listOf package;
      default = [ ];
    };
  };

  config = lib.mkMerge [
    { home.packages = cfg.fonts; }

    (lib.mkIf cfg.enable' {
      fonts = {
        fontconfig.enable = true;
        fonts = with pkgs; [ iosevka-ddd-font iosevka-nerd-font ];
      };
    })
  ];
}
