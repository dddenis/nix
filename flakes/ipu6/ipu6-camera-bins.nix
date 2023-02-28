{ src
, stdenv
, ipuVersion # ipu6 (Tiger Lake) / ipu6ep (Alder Lake)
}:

stdenv.mkDerivation {
  pname = "${ipuVersion}-camera-bin";
  version = src.rev;
  inherit src;

  passthru = {
    inherit ipuVersion;
  };

  sourceRoot = "source/${ipuVersion}";

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp --no-preserve=mode --recursive \
      lib \
      include \
      $out/

    runHook postInstall
  '';

  postFixup = ''
    for pcfile in $out/lib/pkgconfig/*.pc; do
      substituteInPlace $pcfile \
        --replace 'prefix=/usr' "prefix=$out" \
        --replace 'exec_prefix=/usr' 'exec_prefix=''${prefix}' \
        --replace 'libdir=/usr/lib' 'libdir=''${prefix}/lib' \
        --replace 'includedir=/usr/include' 'includedir=''${prefix}/include'
    done
  '';
}
