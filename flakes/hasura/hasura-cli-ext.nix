{ src
, buildNpmPackage
, runtimeShell
, nodejs
}:

buildNpmPackage {
  pname = "hasura-cli-ext";
  version = "2.20.0";
  inherit src;

  npmDepsHash = "sha256-CLoPXElfqT4Bbn3L7MkTNAc429JT++HL4/vEyhzgnC4=";
  sourceRoot = "source/cli-ext";
  npmBuildScript = "transpile";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp -r build node_modules $out/

    cat > $out/bin/cli-ext << EOF
    #!${runtimeShell}
    exec ${nodejs}/bin/node $out/build/command.js "\$@"
    EOF

    chmod +x $out/bin/cli-ext

    runHook postInstall
  '';
}
