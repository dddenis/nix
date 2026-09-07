{ nixpkgs }:
_: prev:

{
  unstable = import nixpkgs {
    inherit (prev) config;
    system = prev.stdenv.hostPlatform.system;

    overlays = [
      (final: prev: prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        visidata = prev.visidata.overrideAttrs (oldAttrs: {
          nativeInstallCheckInputs = (oldAttrs.nativeInstallCheckInputs or [ ]) ++ [
            final.writableTmpDirAsHomeHook
          ];

          # VisiData 3.4 ignores XDG_DATA_HOME on Darwin; expose its macro fixtures
          # under the native data path inside the temporary build home.
          preCheck = (oldAttrs.preCheck or "") + ''
            mkdir -p "$HOME/Library/Application Support"
            ln -s "$PWD/tests/xdg/data/visidata" "$HOME/Library/Application Support/visidata"
          '';
        });
      })
    ];
  };
}
