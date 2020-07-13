{ config, lib, ... }:

let cfg = config.programs.vim.coc-haskell;

in {
  options.programs.vim.coc-haskell.enable' =
    lib.mkEnableOption "vim.coc-haskell";

  config = lib.mkIf cfg.enable' {
    programs.vim.coc-nvim.coc-settings = {
      languageserver = {
        haskell = {
          command = "hie";
          args = [ "--lsp" ];
          rootPatterns =
            [ "*.cabal" "stack.yaml" "cabal.project" "package.yaml" ];
          filetypes = [ "hs" "lhs" "haskell" ];
          initializationOptions = {
            languageServerHaskell = { "hlintOn" = true; };
          };
        };
      };
    };
  };
}
