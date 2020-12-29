{ config, lib, pkgs, ... }:

let cfg = config.programs.alacritty;

in {
  options.programs.alacritty.enable' = lib.mkEnableOption "alacritty";

  config = lib.mkIf cfg.enable' {
    programs.alacritty = {
      enable = true;

      settings = {
        window.startup_mode = "Maximized";

        font = {
          size = 12;

          normal.family = "monospace";
          bold.style = "Bold";
          italic.style = "Oblique";
          bold_italic.style = "Bold Oblique";
        };

        colors = config.theme // (with config.theme; {
          cursor = {
            text = primary.background;
            cursor = normal.white;
          };
        });
      };
    };

    programs.tmux.extraConfig = ''
      set -sa terminal-overrides ',alacritty*:Tc'
    '';
  };
}
