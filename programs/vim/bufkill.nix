{ config, lib, pkgs, ... }:

let
  inherit (config.programs.vim) leader;

  cfg = config.programs.vim.bufkill;

in {
  options.programs.vim.bufkill.enable' = lib.mkEnableOption "vim.bufkill";

  config = lib.mkIf cfg.enable' {
    programs.neovim = {
      extraConfig = ''
        nnoremap <silent> <${leader}>bd :BD<CR>
        nnoremap <silent> <${leader}>bD :BD!<CR>
      '';

      plugins = with pkgs.vimPlugins; [ vim-bufkill ];
    };
  };
}
