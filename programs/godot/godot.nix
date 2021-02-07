{ manifest, stdenv, autoPatchelfHook, fetchurl, unzip, alsaLib, libGL, libX11
, libXcursor, libXi, libXinerama, libXrandr, libXrender, libpulseaudio }:

stdenv.mkDerivation rec {
  inherit (manifest) pname version src;

  nativeBuildInputs = [ autoPatchelfHook unzip ];

  buildInputs = [
    alsaLib
    libGL
    libX11
    libXcursor
    libXi
    libXinerama
    libXrandr
    libXrender
    libpulseaudio
  ];

  unpackCmd = "unzip $curSrc -d source";

  installPhase = ''
    mkdir -p $out/bin
    install -m 0755 ${manifest.binName} $out/bin/godot
  '';
}
