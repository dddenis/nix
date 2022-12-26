{ neovimPkgs, ... }:

{
  config.programs.ddd.neovim.customRC = ''
    local parser_install_dir = vim.fn.stdpath('cache') .. '/parsers'
    vim.opt.runtimepath:append(parser_install_dir)

    require'nvim-treesitter.install'.compilers = { '${neovimPkgs.gcc}/bin/gcc' }
    require'nvim-treesitter.configs'.setup {
      auto_install = true,
      parser_install_dir = parser_install_dir,

      indent = {
        enable = true,
      },

      highlight = {
        enable = true,
      },
    }
  '';

  config.programs.ddd.neovim.packages = with neovimPkgs; [
    tree-sitter
  ];

  config.programs.ddd.neovim.plugins = with neovimPkgs.vimPlugins; [
    treesitter
  ];
}
