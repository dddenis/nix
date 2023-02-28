{ src
, stdenv
}:

stdenv.mkDerivation {
  pname = "ivsc-firmware";
  version = src.rev;
  inherit src;

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/firmware/vsc/soc_a1_prod/
    for f in ./firmware/*.bin; do
      newName="$(basename $f)"
      newName="''${newName%%.bin}_a1_prod.bin"
      mv "$f" "$out/lib/firmware/vsc/soc_a1_prod/$newName"
    done

    runHook postInstall
  '';
}
