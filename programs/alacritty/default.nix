{ config, lib, pkgs, ... }:

let cfg = config.programs.alacritty;

in {
  options.programs.alacritty.enable' = lib.mkEnableOption "alacritty";

  config = lib.mkIf cfg.enable' {
    fonts.fonts = with pkgs; [ iosevka-ddd-font ];

    programs.alacritty = {
      enable = true;

      settings = {
        font = {
          size = 12;

          normal = {
            family = "Iosevka DDD";
            style = "Extended";
          };
          bold.style = "Bold Extended";
          italic.style = "Extended Oblique";
          bold_italic.style = "Bold Extended Oblique";
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
