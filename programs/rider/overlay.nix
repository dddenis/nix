self: super:

let
  pkgs = import (builtins.fetchGit {
    name = "nixos-unstable-rider-2020.1.3";
    url = "https://github.com/nixos/nixpkgs-channels/";
    ref = "refs/heads/nixos-unstable";
    rev = "bd0d0e935c54890dfd9e0f26dce80f72f4749ddb";
  }) { overlays = [ ]; };

in {
  jetbrains = super.jetbrains // {
    rider = pkgs.jetbrains.rider.overrideDerivation (attrs: rec {
      patchPhase = attrs.patchPhase + ''
        rm -rf lib/ReSharperHost/linux-x64/dotnet
        ln -s ${super.dotnet-sdk_3} lib/ReSharperHost/linux-x64/dotnet
      '';
    });
  };
}
