{ iosevka, nerdfonts }:

{
  ddd = iosevka.override {
    set = "ddd";

    privateBuildPlan = {
      family = "Iosevka DDD";
      design = [ "sp-term" ];

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
  };

  nerd = nerdfonts.override { fonts = [ "Iosevka" ]; };
}
