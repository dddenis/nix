{ config, lib, pkgs, ... }:

let cfg = config.programs.vim.go;

in {
  options.programs.vim.go.enable' = lib.mkEnableOption "vim.go";

  config = lib.mkIf cfg.enable' (lib.mkMerge [
    (lib.mkIf config.programs.vim.coc-nvim.enable' {
      programs.neovim.plugins = with pkgs.vimPlugins; [ coc-go ];

      programs.vim.coc-nvim.coc-settings = {
        "go.goplsPath" = "${pkgs.gopls}/bin/gopls";
      };
    })
  ]);
}
