{ config, lib, pkgs, ... }:

let cfg = config.programs.emacs;

in {
  options.programs.emacs.enable' = lib.mkEnableOption "emacs";

  config = lib.mkIf cfg.enable' {
    programs.emacs.enable = true;

    fonts.fonts = with pkgs; [ emacs-all-the-icons-fonts ];

    home = {
      packages = with pkgs; [ gitAndTools.delta nixfmt ];
      sessionPath = [ "${config.home.homeDirectory}/.emacs.d/bin" ];
    };
  };
}
