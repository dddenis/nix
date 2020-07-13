{ config, lib, pkgs, ... }:

let cfg = config.programs.vim.hardtime;

in {
  options.programs.vim.hardtime.enable' = lib.mkEnableOption "vim.hardtime";

  config = lib.mkIf cfg.enable' {
    programs.neovim = {
      extraConfig = ''
        let g:hardtime_default_on = 1
      '';

      plugins = with pkgs.vimPlugins; [ vim-hardtime ];
    };
  };
}
