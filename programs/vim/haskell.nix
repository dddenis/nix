{ config, lib, pkgs, ... }:

let cfg = config.programs.vim.haskell;

in {
  options.programs.vim.haskell.enable' = lib.mkEnableOption "vim.haskell";

  config = lib.mkIf cfg.enable' (lib.mkMerge [
    {
      programs.neovim.extraConfig = ''
        let g:haskell_enable_quantification = 1
        let g:haskell_enable_recursivedo = 1
        let g:haskell_enable_arrowsyntax = 1
        let g:haskell_enable_pattern_synonyms = 1
        let g:haskell_enable_typeroles = 1
        let g:haskell_enable_static_pointers = 1
        let g:haskell_backpack = 1
      '';
    }
    (lib.mkIf config.programs.vim.coc-nvim.enable' {
      programs.vim.coc-nvim.coc-settings = {
        languageserver = {
          haskell = {
            command = "haskell-language-server";
            args = [ "--lsp" "-d" ];
            rootPatterns = [
              "*.cabal"
              "stack.yaml"
              "cabal.project"
              "package.yaml"
              "hie.yaml"
            ];
            filetypes = [ "haskell" "lhaskell" ];
            initializationOptions = {
              haskell = {
                plugin = {
                  "ghcide-completions" = { config = { snippetsOn = false; }; };
                };
              };
            };
          };
        };
      };
    })
  ]);
}
