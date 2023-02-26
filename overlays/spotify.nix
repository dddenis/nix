_: prev:

{
  spotify = prev.spotify.override {
    nss = prev.nss_latest;
  };
}
