{ config, lib, ... }:

let cfg = config.programs.alacritty;

in lib.mkIf cfg.enable' {
  programs.alacritty.settings.font = {
    size = 16;

    normal = {
      family = "Iosevka DDD";
      style = "Extended";
    };
    bold.style = "Bold Extended";
    italic.style = "Extended Oblique";
    bold_italic.style = "Bold Extended Oblique";
  };
}
