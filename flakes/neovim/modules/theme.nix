{ pkgs, ... }:

{
  config.programs.ddd.neovim.customRC = ''
    vim.opt.termguicolors = true
    vim.cmd'colorscheme gruvbox-material'
  '';

  config.programs.ddd.neovim.plugins = with pkgs.ddd.vimPlugins; [
    gruvbox-material
  ];
}
