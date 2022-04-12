{ config, lib, pkgs, ... }:

let
  inherit (config.programs.vim) leader;

  cfg = config.programs.vim.git;

in {
  options.programs.vim.git.enable' = lib.mkEnableOption "vim.git";

  config = lib.mkIf cfg.enable' {
    hm.programs.neovim.plugins = with pkgs.vimPlugins; [ vim-fugitive vim-gitgutter ];
  };
}
