{ src
, stdenv
, autoreconfHook
, pkg-config
, gst_all_1
, ipu6-camera-hal
, libdrm
}:

stdenv.mkDerivation rec {
  pname = "${ipu6-camera-hal.ipuVersion}-icamerasrc";
  version = src.rev;
  inherit src;

  enableParallelBuilding = true;

  nativeBuildInputs = [
    autoreconfHook
    pkg-config
  ];

  buildInputs = [
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    ipu6-camera-hal
    libdrm
  ];

  preConfigure = ''
    # https://github.com/intel/ipu6-camera-hal/issues/1
    export CHROME_SLIM_CAMHAL=ON
    # https://github.com/intel/icamerasrc/issues/22
    export STRIP_VIRTUAL_CHANNEL_CAMHAL=ON

    export CPPFLAGS="-I${gst_all_1.gst-plugins-base.dev}/include/gstreamer-1.0"
  '';
}
