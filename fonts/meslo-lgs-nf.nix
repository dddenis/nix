{ fetchFromGitHub, stdenv, unzip }:

let rev = "54fbc18e";

in stdenv.mkDerivation rec {
  pname = "meslo-lgs-nf";
  version = rev;

  src = fetchFromGitHub {
    owner = "romkatv";
    repo = "powerlevel10k-media";
    inherit rev;
    sha256 = "03nzksq2ghclwbrsbg84lqq3n4ngr1vq4yi3qipm7qyvavc4d4mx";
  };

  installPhase = ''
    mkdir -p $out/share/fonts/truetype
    cp *.ttf $out/share/fonts/truetype
  '';

  outputs = [ "out" ];

  meta = {
    description = "MesloLGS Nerd Font";
    homepage = "https://github.com/romkatv/powerlevel10k-media/";
    license = stdenv.lib.licenses.asl20;
    platforms = with stdenv.lib.platforms; all;
  };
}
