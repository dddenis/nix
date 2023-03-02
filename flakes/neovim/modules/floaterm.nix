{ neovimPkgs, ... }:

{
  config.programs.ddd.neovim.customRC = ''
    vim.g.floaterm_opener = 'edit'

    map('n', '<leader>.', ':FloatermNew lf<cr>')
  '';

  config.programs.ddd.neovim.plugins = with neovimPkgs.vimPlugins; [
    floaterm
  ];
}
