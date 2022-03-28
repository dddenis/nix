{ config, lib, pkgs, ... }:

let
  inherit (config.programs.vim) leader;
  cfg = config.programs.vim.floaterm;

in {
  options.programs.vim.floaterm.enable' = lib.mkEnableOption "vim.floaterm";

  config = lib.mkIf cfg.enable' {
    hm.programs.neovim = {
      extraConfig = ''
        let g:floaterm_opener = "edit"

        noremap <${leader}>. :FloatermNew nnn<CR>
      '';

      plugins = with pkgs.vimPlugins; [ vim-floaterm ];
    };
  };
}
