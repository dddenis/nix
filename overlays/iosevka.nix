_: prev:

{
  ddd.iosevka-font = prev.iosevka.override {
    set = "iosevka-ddd";

    privateBuildPlan = {
      family = "Iosevka DDD";
      spacing = "fontconfig-mono";
      serifs = "sans";
      no-cv-ss = true;

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
    };
  };

  ddd.iosevka-nerd-font = prev.nerdfonts.override { fonts = [ "Iosevka" ]; };
}