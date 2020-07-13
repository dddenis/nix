{ config, lib, ... }:

let cfg = config.xresources;

in {
  options.xresources.enable' = lib.mkEnableOption "xresources";

  config = lib.mkIf cfg.enable' {
    xresources.properties = with config.theme; {
      "*foreground" = primary.foreground;
      "*background" = primary.background;
      "*cursorColor" = normal.white;

      "*color0" = normal.black;
      "*color1" = normal.red;
      "*color2" = normal.green;
      "*color3" = normal.yellow;
      "*color4" = normal.blue;
      "*color5" = normal.magenta;
      "*color6" = normal.cyan;
      "*color7" = normal.white;

      "*color8" = bright.black;
      "*color9" = bright.red;
      "*color10" = bright.green;
      "*color11" = bright.yellow;
      "*color12" = bright.blue;
      "*color13" = bright.magenta;
      "*color14" = bright.cyan;
      "*color15" = bright.white;
    };
  };
}
