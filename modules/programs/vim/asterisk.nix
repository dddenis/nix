{ config, lib, pkgs, ... }:

let
  inherit (config.programs.vim) leader;

  cfg = config.programs.vim.asterisk;

in {
  options.programs.vim.asterisk.enable' = lib.mkEnableOption "vim.asterisk";

  config = lib.mkIf cfg.enable' {
    hm.programs.neovim = {
      extraConfig = ''
        map * <Plug>(asterisk-z*)
        map # <Plug>(asterisk-z#)
        map g* <Plug>(asterisk-gz*)
        map g# <Plug>(asterisk-gz#)
      '';

      plugins = with pkgs.vimPlugins; [ vim-asterisk ];
    };
  };
}
