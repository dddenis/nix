{ src
, stdenv
, automake
, autoconf
, autoreconfHook
, pkg-config
, gst_all_1
}:

stdenv.mkDerivation rec {
  pname = "v4l2-relayd";
  version = src.rev;
  inherit src;

  nativeBuildInputs = [
    automake
    autoconf
    autoreconfHook
    pkg-config
  ];

  buildInputs = [
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
  ];
}
