{ src
, buildGoModule
, makeWrapper
, hasura-cli-ext
}:

buildGoModule rec {
  pname = "hasura-cli";
  version = "2.20.0";
  inherit src;

  modRoot = "cli";
  subPackages = [ "cmd/hasura" ];
  vendorHash = "sha256-vZKPVQ/FTHnEBsRI5jOT6qm7noGuGukWpmrF8fK0Mgs=";

  nativeBuildInputs = [
    makeWrapper
  ];

  ldflags = [
    "-s"
    "-w"
    "-extldflags '-static'"
    "-X github.com/hasura/graphql-engine/cli/v2/version.BuildVersion=v${version}"
  ];

  postInstall = ''
    wrapProgram $out/bin/hasura \
      --add-flags "--cli-ext-path" \
      --add-flags "${hasura-cli-ext}/bin/cli-ext"
  '';
}
