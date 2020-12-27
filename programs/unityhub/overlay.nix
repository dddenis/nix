self: super:

{
  unity-androidenv = super.callPackage ./androidenv.nix { };

  # 2.4.2
  unityhub = super.unityhub.override {
    fetchurl = _:
      super.fetchurl {
        url = "https://public-cdn.cloud.unity3d.com/hub/prod/UnityHub.AppImage";
        sha256 = "mtx2mK36ZHn4NysLo157HX4q4l89d84jhmyws832gVQ=";
      };
  };
}
