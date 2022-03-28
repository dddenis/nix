{ config, lib, ... }:

let
  themeSubmodule = lib.types.submodule {
    options = {
      primary = mkColorSubmodule [ "background" "foreground" ];
      normal = mk8ColorSubmodule;
      bright = mk8ColorSubmodule;
    };
  };

  mkColorSubmodule = names:
    lib.mkOption {
      type = lib.types.submodule {
        options = builtins.listToAttrs (map (name: {
          inherit name;
          value = mkColor;
        }) names);
      };
    };

  mk8ColorSubmodule = mkColorSubmodule [
    "black"
    "red"
    "green"
    "yellow"
    "blue"
    "magenta"
    "cyan"
    "white"
  ];

  mkColor = lib.mkOption { type = lib.types.str; };

in {
  options = {
    theme = lib.mkOption { type = themeSubmodule; };
    themes = lib.mkOption { type = lib.types.attrsOf (themeSubmodule); };
  };

  config.theme = config.themes.gruvbox;

  config.hm.xresources.properties = with config.theme; {
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
}
