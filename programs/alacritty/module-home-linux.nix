{ config, lib, ... }:

let cfg = config.programs.alacritty;

in lib.mkIf cfg.enable' {
  programs.alacritty.settings.font = {
    size = 10;

    normal.family = "monospace";
    bold.style = "Bold";
    italic.style = "Oblique";
    bold_italic.style = "Bold Oblique";
  };
}
