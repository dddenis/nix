{ config, lib, pkgs, ... }:

let
  cfg = config.programs.fzf;
  fd = "${pkgs.fd}/bin/fd";
  tree = "${pkgs.tree}/bin/tree";

in {
  options.programs.fzf.enable' = lib.mkEnableOption "fzf";

  config = lib.mkIf cfg.enable' {
    programs.fzf = {
      enable = true;
      enableZshIntegration = true;

      changeDirWidgetCommand = "${fd} --type d";
      changeDirWidgetOptions = [ "--preview '${tree} -C {} | head -200'" ];
      defaultCommand = "${fd} --type f --hidden --exclude .git";
      defaultOptions = [ "--height 40%" "--border" ];
      fileWidgetCommand = "${fd} --type f --hidden --exclude .git";
    };

    programs.zsh.initExtra = ''
      _fzf_compgen_path() {
        ${fd} --hidden --follow --exclude .git . "$1"
      }

      _fzf_compgen_dir() {
        ${fd} --type d --hidden --follow --exclude .git . "$1"
      }
    '';
  };
}
