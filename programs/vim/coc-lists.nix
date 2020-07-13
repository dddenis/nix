{ config, lib, pkgs, ... }:

let
  inherit (config.programs.vim) leader;

  cfg = config.programs.vim.coc-lists;

in {
  options.programs.vim.coc-lists.enable' = lib.mkEnableOption "vim.coc-lists";

  config = lib.mkIf cfg.enable' {
    programs.neovim = {
      extraConfig = ''
        nnoremap <silent> <${leader}><${leader}> :<C-u>CocList files<CR>
        nnoremap <silent> <${leader}>, :<C-u>CocList buffers<CR>
        nnoremap <silent> <${leader}>sp :<C-u>CocList grep<CR>

        nnoremap <${leader}>sP :Rg<Space>
        command! -nargs=+ -complete=custom,s:GrepArgs Rg exe 'CocList grep '.<q-args>
        function! s:GrepArgs(...)
          let list = ['-S', '-smartcase', '-i', '-ignorecase', '-w', '-word',
            \ '-e', '-regex', '-u', '-skip-vcs-ignores', '-t', '-extension']
          return join(list, "\n")
        endfunction
      '';

      plugins = with pkgs.vimPlugins; [ coc-lists ];
    };

    programs.vim.coc-nvim.coc-settings = {
      "list.source.files.command" = "fd";
      "list.source.files.args" = [ "--type" "f" "--hidden" "--exclude" ".git" ];

      "list.source.grep.defaultArgs" = [ "-smartcase" ];
    };
  };
}
