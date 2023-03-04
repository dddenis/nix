{ src
, buildGoModule
, makeWrapper
, hasura-cli
}:

buildGoModule rec {
  pname = "nhost-cli";
  version = "0.8.24";
  inherit src;

  vendorHash = null;

  nativeBuildInputs = [
    makeWrapper
  ];

  ldflags = [
    "-s"
    "-w"
    "-X github.com/nhost/cli/cmd.Version=v${version}"
  ];

  postInstall = ''
    mv $out/bin/cli $out/bin/nhost

    wrapProgram $out/bin/nhost \
      --set "HASURACLI" "${hasura-cli}/bin/hasura"
  '';
}
