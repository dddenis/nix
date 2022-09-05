_: prev:

let
  inherit (prev) lib;

  pluginPrefix = "vim-plugin-";

in
{
  lib = lib // {
    ddd = (lib.ddd or { }) // rec {
      filterPlugins = lib.attrsets.filterAttrs (name: _: lib.strings.hasPrefix pluginPrefix name);

      buildPlugin = name: src:
        let
          pname = lib.strings.removePrefix pluginPrefix name;

          base = {
            inherit pname;
            version = src.shortRev;
            src = src;
          };

          extra = {
            telescope-fzf-native = { buildPhase = "make"; };
          };
        in
        prev.vimUtils.buildVimPluginFrom2Nix
          (base // lib.attrsets.attrByPath [ pname ] { } extra);

      toLua = with builtins; value:
        if value == null then
          "nil"
        else if isList value then
          "{
            ${lib.concatMapStringsSep ",\n" toLua value}
          }"
        else if isAttrs value then
          "{
            ${lib.concatStringsSep ",\n" (lib.mapAttrsToList (k: v: "[${toLua k}] = ${toLua v}") value)}
          }"
        else
          toJSON value;
    };
  };
}
