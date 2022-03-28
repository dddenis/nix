{ config, lib, pkgs, ... }:

let
  inherit (config.programs.vim) leader;

  cfg = config.programs.vim.fzf;

in {
  options.programs.vim.fzf.enable' = lib.mkEnableOption "vim.fzf";

  config = lib.mkIf cfg.enable' {
    hm.programs.neovim = {
      extraConfig = ''
        let $FZF_DEFAULT_OPTS .= ' --reverse'
        let g:fzf_history_dir = '~/.local/share/fzf/history'

        nnoremap <silent> <${leader}><${leader}> :<C-u>Files<CR>
        nnoremap <silent> <${leader}>, :<C-u>Buffers<CR>
        nnoremap <silent> <${leader}>fr :<C-u>History<CR>

        command! -nargs=* -bang Rg call RipgrepFzf(<q-args>, "", <bang>0)
        nnoremap <silent> <${leader}>sp :<C-u>Rg<CR>

        command! -nargs=* -bang RgDir call RipgrepFzf(<q-args>, expand('%:h'), <bang>0)
        nnoremap <silent> <${leader}>s. :<C-u>RgDir<CR>

        function! RipgrepFzf(options, path, fullscreen)
          let command_fmt = 'rg --column --line-number --no-heading --color=always --smart-case --hidden --glob "!.git" %s %s %s || true'
          let initial_command = printf(command_fmt, a:options, '"!@#$%^&*()"', a:path)
          let reload_command = printf(command_fmt, a:options, '{q}', a:path)
          let spec = {'options': ['--disabled', '--bind', 'change:reload:sleep 0.1;'.reload_command]}
          call fzf#vim#grep(initial_command, 1, fzf#vim#with_preview(spec), a:fullscreen)
        endfunction
      '';

      plugins = with pkgs.vimPlugins; [ fzf-vim ];
    };
  };
}
