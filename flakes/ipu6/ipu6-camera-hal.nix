{ src
, stdenv
, cmake
, pkg-config
, expat
, ipu6-camera-bin
, libtool
, gst_all_1
}:

stdenv.mkDerivation {
  pname = "${ipu6-camera-bin.ipuVersion}-camera-hal";
  version = src.rev;
  inherit src;

  passthru = {
    ipuVersion = ipu6-camera-bin.ipuVersion;
  };

  enableParallelBuilding = true;

  nativeBuildInputs = [
    cmake
    pkg-config
  ];

  buildInputs = [
    expat
    ipu6-camera-bin
    libtool
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
  ];

  cmakeFlags = [
    "-DIPU_VER=${ipu6-camera-bin.ipuVersion}"
    "-DUSE_PG_LITE_PIPE=ON"
    "-DCMAKE_INSTALL_PREFIX=${placeholder "out"}"
  ];

  postFixup = ''
    for pcfile in $out/lib/pkgconfig/*.pc; do
      substituteInPlace $pcfile \
        --replace 'prefix=/usr' "prefix=$out"
    done
  '';
}
