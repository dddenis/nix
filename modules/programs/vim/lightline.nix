{ config, lib, pkgs, ... }:

let cfg = config.programs.vim.lightline;

in {
  options.programs.vim.lightline.enable' = lib.mkEnableOption "vim.lightline";

  config = lib.mkIf cfg.enable' {
    hm.programs.neovim = {
      extraConfig = ''
        set noshowmode

        let g:lightline = {
          \ 'colorscheme': 'gruvbox_material',
          \ 'active': {
          \   'left': [
          \     [ 'mode', 'paste' ],
          \     [ 'cocstatus', 'readonly', 'filename', 'modified' ]
          \   ]
          \ },
          \ 'component_function': {
          \   'cocstatus': 'coc#status'
          \ },
          \ }
      '';

      plugins = with pkgs.vimPlugins; [ lightline-vim ];
    };
  };
}
