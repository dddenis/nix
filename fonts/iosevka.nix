{ fetchzip, iosevka }:

let
  commonPrivateBuildPlan = {
    design = [ "extended" ];

    weights = {
      regular = {
        shape = 400;
        menu = 400;
        css = 400;
      };

      bold = {
        shape = 700;
        menu = 700;
        css = 700;
      };
    };

    slants = {
      upright = "normal";
      italic = "oblique";
    };
  };

in {
  ddd = iosevka.override {
    set = "ddd";

    privateBuildPlan = commonPrivateBuildPlan // {
      family = "Iosevka DDD";
      design = commonPrivateBuildPlan.design ++ [ "calt" "ligset-haskell" ];
    };
  };

  ddd-term = iosevka.override {
    set = "ddd-term";

    privateBuildPlan = commonPrivateBuildPlan // {
      family = "Iosevka DDD Term";
      design = commonPrivateBuildPlan.design ++ [ "term" ];
    };
  };

  nerd = fetchzip {
    name = "iosevka-nerd-font";

    url =
      "https://github.com/ryanoasis/nerd-fonts/releases/download/v2.0.0/Iosevka.zip";

    postFetch = ''
      mkdir -p $out/share/fonts/iosevka-nerd
      unzip -j $downloadedFile -d $out/share/fonts/iosevka-nerd
    '';

    sha256 = "13yyv7s901x3z74y5314qjxsacdq26idn4gwixgl7c2q7c6rv8i9";
  };
}
