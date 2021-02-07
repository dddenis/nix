{
  mkManifest = { v, sha256, release ? "stable", mono ? false }:
    let
      version = "${v}-${release}";
      ifMono = x: if mono then x else "";
      mkBinName = sep: "Godot_v${version}_${ifMono "mono_"}x11${sep}64";

    in rec {
      inherit version;
      pname = "godot" + (ifMono "-mono");

      src = builtins.fetchurl {
        inherit sha256;

        url = let
          _release = if release == "stable" then "" else "${release}/";
          _mono = ifMono "mono/";
          _binName = if mono then mkBinName "_" else binName;

        in "https://downloads.tuxfamily.org/godotengine/${v}/${_release}${_mono}${_binName}.zip";
      };

      binName = mkBinName ".";
    };
}
