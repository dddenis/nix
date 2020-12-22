self: super:

let
  mkCustomLib = lib:
    let callLibs = file: import file { inherit lib; };

    in {
      inherit (callLibs ./attrsets.nix) concatAttrs;
      inherit (callLibs ./lists.nix) isEmpty;
      inherit (callLibs ./trivial.nix) withDefault;

      fs = callLibs ./fs.nix;
      user = callLibs ./user.nix;
    };

in { lib = super.lib.extend (self: mkCustomLib); }
