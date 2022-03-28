{ config, lib, pkgs, ... }:

let cfg = config.programs.alacritty;

in {
  options.programs.alacritty.enable' = lib.mkEnableOption "alacritty";

  config = lib.mkIf cfg.enable' {
    hm.programs.alacritty = {
      enable = true;

      settings = {
        colors = config.theme // (with config.theme; {
          cursor = {
            text = primary.background;
            cursor = normal.white;
          };
        });

        font = {
          size = 12;

          normal.family = "monospace";
          bold.style = "Bold";
          italic.style = "Oblique";
          bold_italic.style = "Bold Oblique";
        };

        window = {
          decorations = "none";
          startup_mode = "Maximized";
        };
      };
    };

    hm.programs.tmux.extraConfig = ''
      set -as terminal-features ",alacritty*:RGB"
    '';
  };
}

