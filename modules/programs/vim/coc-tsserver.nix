{ config, lib, pkgs, ... }:

let cfg = config.programs.vim.coc-tsserver;

in {
  options.programs.vim.coc-tsserver.enable' =
    lib.mkEnableOption "vim.coc-tsserver";

  config = lib.mkIf cfg.enable' {
    programs.vim.coc-nvim.coc-settings = {
      "javascript.suggest.completeFunctionCalls" = false;
      "typescript.suggest.completeFunctionCalls" = false;
    };

    hm.programs.neovim.plugins = with pkgs.vimPlugins; [ coc-tsserver ];
  };
}
