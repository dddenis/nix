{ buildRubyGem }:

buildRubyGem rec {
  name = "${gemName}-${version}";
  gemName = "shopify-cli";
  version = "2.6.5";
  source.sha256 =
    "Eq55IGAUbYmJ22+v0OtE9wJLu62WcdzcE0dKMg09FKA=";

  buildFlags = [ "--skip-cli-build" ];

  postInstall = ''
    ln -s "$GEM_HOME/gems/$name/bin/shopify" "$out/bin"
  '';
}
