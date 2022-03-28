{ config, lib, pkgs, ... }:

let cfg = config.programs.vim.rust;

in {
  options.programs.vim.rust.enable' = lib.mkEnableOption "vim.rust";

  config = lib.mkIf cfg.enable' (lib.mkMerge [
    { hm.programs.neovim.extraPackages = with pkgs; [ clippy rustfmt ]; }

    (lib.mkIf config.programs.vim.coc-nvim.enable' {
      hm.programs.neovim.plugins = with pkgs.vimPlugins; [ coc-rust-analyzer ];

      programs.vim.coc-nvim.coc-settings = {
        "rust-analyzer.checkOnSave.command" = "clippy";
        "rust-analyzer.serverPath" = "${pkgs.rust-analyzer}/bin/rust-analyzer";
      };
    })
  ]);
}
