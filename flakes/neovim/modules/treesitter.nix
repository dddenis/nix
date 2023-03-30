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

      context_commentstring = {
        enable = true,
        enable_autocmd = false,
      },
    }

    require'Comment'.setup({
      pre_hook = require('ts_context_commentstring.integrations.comment_nvim').create_pre_hook(),
    })
  '';

  config.programs.ddd.neovim.packages = with neovimPkgs; [
    tree-sitter
  ];

  config.programs.ddd.neovim.plugins = with neovimPkgs.vimPlugins; [
    comment
    treesitter
    ts-context-commentstring
  ];
}
