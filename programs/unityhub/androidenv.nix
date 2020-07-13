{ androidenv }:

androidenv.composeAndroidPackages {
  toolsVersion = "26.1.1";
  platformToolsVersion = "29.0.6";
  buildToolsVersions = [ "28.0.3" ];
  platformVersions = [ "28" ];
  abiVersions = [ "x86" "x86_64" ];
  includeNDK = true;
}
