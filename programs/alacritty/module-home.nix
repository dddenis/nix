{ config, lib, pkgs, ... }:

let cfg = config.programs.alacritty;

in {
  options.programs.alacritty.enable' = lib.mkEnableOption "alacritty";

  config = lib.mkIf cfg.enable' {
    programs.alacritty = {
      enable = true;

      settings = {
        window.startup_mode = "Maximized";

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
