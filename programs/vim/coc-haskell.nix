{ config, lib, ... }:

let cfg = config.programs.vim.coc-haskell;

in {
  options.programs.vim.coc-haskell.enable' =
    lib.mkEnableOption "vim.coc-haskell";

  config = lib.mkIf cfg.enable' {
    programs.vim.coc-nvim.coc-settings = {
      languageserver = {
        haskell = {
          command = "haskell-language-server-wrapper";
          args = [ "--lsp" "-d" ];
          rootPatterns = [
            "*.cabal"
            "stack.yaml"
            "cabal.project"
            "package.yaml"
            "hie.yaml"
          ];
          filetypes = [ "haskell" "lhaskell" ];
          initializationOptions = { haskell = { }; };
        };
      };
    };
  };
}
