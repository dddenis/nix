{
  nixpkgs.overlays = [
    (_: prev: {
      kmonad = prev.stdenv.mkDerivation {
        name = "kmonad";
        src = builtins.fetchurl {
          url =
            "https://github.com/david-janssen/kmonad/releases/download/0.4.1/kmonad-0.4.1-linux";
          sha256 = "13vs7xq9clgg6pd9gr49h5ljgyg0kc63qd3ghh3dvmi3rkkmi7l3";
        };

        phases = [ "installPhase" ];

        installPhase = ''
          mkdir -p $out/bin
          cp $src $out/bin/kmonad
          chmod +x $out/bin/kmonad
        '';
      };
    })
  ];
}
