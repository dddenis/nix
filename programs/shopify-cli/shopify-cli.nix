{ buildRubyGem }:

buildRubyGem rec {
  name = "${gemName}-${version}";
  gemName = "shopify-cli";
  version = "2.4.0";
  source.sha256 =
    "962a4d8ea0f656646511b0f04300f48abb4072fa858d649061dbf5399735d73e";

  buildFlags = [ "--skip-cli-build" ];

  postInstall = ''
    ln -s "$GEM_HOME/gems/$name/bin/shopify" "$out/bin"
  '';
}
