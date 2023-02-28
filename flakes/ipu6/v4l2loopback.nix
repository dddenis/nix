{ src
, v4l2loopback
}:

v4l2loopback.overrideAttrs (_: rec {
  version = src.rev;
  inherit src;

  prePatch = ''
    patches="$(echo debian/patches/*.patch)"
  '';
})

