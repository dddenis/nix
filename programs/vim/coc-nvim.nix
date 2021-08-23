{ config, lib, pkgs, ... }:

let
  inherit (lib) types;
  inherit (config.programs.vim) leader;

  cfg = config.programs.vim.coc-nvim;

in {
  imports =
    [ ./coc-diagnostic.nix ./coc-lists.nix ./coc-sh.nix ./coc-tsserver.nix ];

  options.programs.vim.coc-nvim = {
    enable' = lib.mkEnableOption "vim.coc-nvim";

    globalExtensions = lib.mkOption {
      type = with lib.types; listOf string;
      default = [ ];
    };

    coc-settings = lib.mkOption { type = types.attrs; };

    filetypeMap = lib.mkOption {
      type = with lib.types; attrsOf string;
      default = { };
    };
  };

  config = lib.mkIf cfg.enable' {
    programs.vim = {
      coc-diagnostic.enable' = true;
      coc-lists.enable' = true;
      coc-sh.enable' = true;
      coc-tsserver.enable' = true;

      coc-nvim.coc-settings = {
        "diagnostic.enableMessage" = "jump";
        "diagnostic.maxWindowHeight" = 32;

        "list.insertMappings" = { "<C-l>" = "do:defaultaction"; };
        "list.normalMappings" = { "<C-l>" = "do:defaultaction"; };

        "suggest.noselect" = false;
      };
    };

    programs.neovim = {
      extraConfig = ''
        let g:coc_filetype_map = ${builtins.toJSON cfg.filetypeMap}
        let g:coc_global_extensions = ${builtins.toJSON cfg.globalExtensions}

        augroup CoC
          autocmd!
          autocmd CursorHold * silent call CocActionAsync('highlight')
          autocmd FileType typescript,json setlocal formatexpr=CocAction('formatSelected')
          autocmd User CocJumpPlaceholder call CocActionAsync('showSignatureHelp')
        augroup end

        set cmdheight=2

        set updatetime=300

        set shortmess+=c

        set signcolumn=yes

        xmap if <Plug>(coc-funcobj-i)
        xmap af <Plug>(coc-funcobj-a)
        omap if <Plug>(coc-funcobj-i)
        omap af <Plug>(coc-funcobj-a)

        inoremap <silent><expr> <C-Space> coc#refresh()

        nmap <silent> gh <Plug>(coc-diagnostic-info)
        nmap <silent> [d <Plug>(coc-diagnostic-prev)
        nmap <silent> ]d <Plug>(coc-diagnostic-next)
        nmap <silent> [e <Plug>(coc-diagnostic-prev-error)
        nmap <silent> ]e <Plug>(coc-diagnostic-next-error)

        nmap <silent> gd <Plug>(coc-definition)
        nmap <silent> gy <Plug>(coc-type-definition)
        nmap <silent> gi <Plug>(coc-implementation)
        nmap <silent> gD <Plug>(coc-references)

        if has('nvim-0.4.0') || has('patch-8.2.0750')
          nnoremap <silent><nowait><expr> J coc#float#has_scroll() ? coc#float#scroll(1) : "J"
          nnoremap <silent><nowait><expr> K coc#float#has_scroll() ? coc#float#scroll(0) : ":call \<SID>show_documentation()\<CR>"
          inoremap <silent><nowait><expr> J coc#float#has_scroll() ? "\<c-r>=coc#float#scroll(1)\<cr>" : "J"
          inoremap <silent><nowait><expr> K coc#float#has_scroll() ? "\<c-r>=coc#float#scroll(0)\<cr>" : "K"
          vnoremap <silent><nowait><expr> J coc#float#has_scroll() ? coc#float#scroll(1) : "J"
          vnoremap <silent><nowait><expr> K coc#float#has_scroll() ? coc#float#scroll(0) : "K"
        endif

        function! s:show_documentation()
          if (index(['vim','help'], &filetype) >= 0)
            execute 'h '.expand('<cword>')
          else
            call CocActionAsync('doHover')
          endif
        endfunction

        nmap <${leader}>cr :CocCommand document.renameCurrentWord<CR>
        nmap <${leader}>cR <Plug>(coc-refactor)

        nmap <${leader}>cf <Plug>(coc-format)
        xmap <${leader}>cf <Plug>(coc-format-selected)

        nmap <${leader}>c. <Plug>(coc-codeaction)
        xmap <${leader}>c. <Plug>(coc-codeaction-selected)
        nmap <${leader}>cc <Plug>(coc-fix-current)
        nmap <${leader}>ca :CocCommand eslint.executeAutofix<CR>
        nmap <${leader}>ci :call CocAction('runCommand', 'editor.action.organizeImport')<CR>

        nmap <${leader}>xx <Plug>(coc-codelens-action)

        nnoremap <silent> <${leader}>cx :<C-u>CocList diagnostics<CR>
        nnoremap <silent> <${leader}>cs :<C-u>CocList -I symbols<CR>
        nnoremap <silent> <${leader}>sl :<C-u>CocList lists<CR>
        nnoremap <silent> <${leader}>se :<C-u>CocList extensions<CR>
        nnoremap <silent> <${leader}>sc :<C-u>CocList commands<CR>
        nnoremap <silent> <${leader}>fr :<C-u>CocList mru<CR>
        nnoremap <silent> <${leader}>sj :<C-u>CocNext<CR>
        nnoremap <silent> <${leader}>sk :<C-u>CocPrev<CR>
        nnoremap <silent> <${leader}>' :<C-u>CocListResume<CR>
      '';

      plugins = with pkgs.vimPlugins; [
        coc-eslint
        coc-json
        coc-nvim
        coc-pairs
        coc-prettier
      ];
    };

    xdg.configFile."nvim/coc-settings.json".text =
      builtins.toJSON cfg.coc-settings;
  };
}
