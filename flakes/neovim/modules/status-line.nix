{ pkgs, ... }:

{
  config.programs.ddd.neovim.customRC = ''
    vim.opt.showmode = false

    require'lualine'.setup({
      sections = {
        lualine_b = {'diff', 'diagnostics'},
      },
    })
  '';

  config.programs.ddd.neovim.plugins = with pkgs.ddd.vimPlugins; [
    lualine
  ];
}
