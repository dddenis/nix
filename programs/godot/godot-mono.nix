{ manifest, lib, makeWrapper, dotnet-sdk_3, fetchurl, godot, msbuild, zlib }:

godot.overrideAttrs (oldAttrs: rec {
  inherit (manifest) pname version src;

  buildInputs = oldAttrs.buildInputs ++ [ makeWrapper zlib ];

  unpackCmd = "";

  installPhase = ''
    mkdir -p $out/bin $out/opt/godot-mono

    install -m 0755 ${manifest.binName} $out/opt/godot-mono/${manifest.binName}
    cp -r GodotSharp $out/opt/godot-mono

    makeWrapper \
      $out/opt/godot-mono/${manifest.binName} \
      $out/bin/godot-mono \
      --prefix PATH : ${lib.makeBinPath [ dotnet-sdk_3 msbuild ]}
  '';
})
