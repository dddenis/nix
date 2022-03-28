{ config, lib, pkgs, ... }:

let cfg = config.programs.vim.tmux;

in {
  options.programs.vim.tmux.enable' = lib.mkEnableOption "vim.tmux";

  config = lib.mkIf cfg.enable' {
    hm.programs.neovim = {
      extraConfig = ''
        let g:tmux_navigator_disable_when_zoomed = 1
      '';

      plugins = with pkgs.vimPlugins; [ vim-tmux-navigator ];
    };
  };
}
