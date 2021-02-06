{ config, lib, pkgs, ... }:

let cfg = config.programs.vim.rust;

in {
  options.programs.vim.rust.enable' = lib.mkEnableOption "vim.rust";

  config = lib.mkIf cfg.enable' (lib.mkMerge [
    { programs.neovim.extraPackages = with pkgs; [ rustfmt ]; }

    (lib.mkIf config.programs.vim.coc-nvim.enable' {
      programs.neovim.plugins = with pkgs.vimPlugins; [ coc-rust-analyzer ];

      programs.vim.coc-nvim.coc-settings = {
        "rust-analyzer.serverPath" = "${pkgs.rust-analyzer}/bin/rust-analyzer";
      };
    })
  ]);
}
