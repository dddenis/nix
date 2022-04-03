{ config, lib, pkgs, ... }:

let cfg = config.programs.st;

in {
  options.programs.st.enable' = lib.mkEnableOption "st";

  config = lib.mkIf cfg.enable' {
    nixpkgs.overlays = [
      (_: prev: {
        ddd-st = prev.st.override {
          conf = import ./_config.nix config;
        };
      })
    ];

    user.packages = [ pkgs.ddd-st ];

    hm.programs.tmux.extraConfig = ''
      set -as terminal-features ",st*:RGB"
    '';
  };
}
