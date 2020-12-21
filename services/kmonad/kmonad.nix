{ stdenv }:

let sources = import ../../nix/sources.nix;

in stdenv.mkDerivation {
  name = "kmonad";
  src = sources.kmonad;

  phases = [ "installPhase" ];

  installPhase = ''
    mkdir -p $out/bin
    cp $src $out/bin/kmonad
    chmod +x $out/bin/kmonad
  '';
}
