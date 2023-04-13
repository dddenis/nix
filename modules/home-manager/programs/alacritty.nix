{ config, lib, pkgs, ... }:

let cfg = config.ddd.programs.alacritty;

in
{
  options.ddd.programs.alacritty.enable = lib.mkEnableOption "alacritty";

  config = lib.mkIf cfg.enable {
    programs.alacritty = {
      enable = true;

      settings = {
        colors = config.theme // (with config.theme; {
          cursor = {
            text = primary.background;
            cursor = normal.white;
          };
        });

        font = {
          size = if pkgs.stdenv.isDarwin then 18 else 13.5;

          normal.family = if pkgs.stdenv.isDarwin then "Iosevka Nerd Font Mono" else "monospace";
          bold.style = "Bold";
          italic.style = "Oblique";
          bold_italic.style = "Bold Oblique";
        };

        window = {
          decorations = "none";
          startup_mode = "Maximized";

          # Fix maximized startup in Wayland
          dimensions = {
            columns = 240;
            lines = 160;
          };
        };
      };
    };

    programs.tmux.extraConfig = ''
      set -as terminal-overrides ",alacritty*:RGB"
    '';
  };
}

