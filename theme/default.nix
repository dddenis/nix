{ lib, ... }:

let
  inherit (lib) types;

  mkColor = lib.mkOption { type = types.str; };

  mkColorSubmodule = names:
    lib.mkOption {
      type = types.submodule {
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

in {
  imports = [ ./gruvbox.nix ];

  options.theme = {
    primary = mkColorSubmodule [ "background" "foreground" ];
    normal = mk8ColorSubmodule;
    bright = mk8ColorSubmodule;
  };
}
