{ neovimPkgs, ... }:

{
  config.programs.ddd.neovim.customRC = ''
    vim.opt.termguicolors = true
    vim.cmd'colorscheme gruvbox-material'
  '';

  config.programs.ddd.neovim.plugins = with neovimPkgs.vimPlugins; [
    gruvbox-material
  ];
}
