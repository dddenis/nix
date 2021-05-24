{ config, lib, pkgs, ... }:

let
  cfg = config.programs.lazygit;
  delta = "${pkgs.delta}/bin/delta";
  lazygit = "${pkgs.lazygit}/bin/lazygit";

in {
  options.programs.lazygit.enable' = lib.mkEnableOption "lazygit";

  config = lib.mkIf cfg.enable' {
    programs = {
      lazygit = {
        enable = true;

        settings = {
          git.paging = {
            colorArg = "always";
            pager = "${delta} --paging=never";
          };

          gui.showCommandLog = false;
        };
      };

      zsh.shellAliases = { gg = lazygit; };
    };
  };
}
