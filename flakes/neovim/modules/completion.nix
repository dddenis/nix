{ pkgs, ... }:

{
  config.programs.ddd.neovim.customRC = ''
    local cmp = require'cmp'

    cmp.setup {
      completion = {
        completeopt = 'menu,menuone',
      },
      snippet = {
        expand = function(args)
          require'luasnip'.lsp_expand(args.body)
        end,
      },
      mapping = cmp.mapping.preset.insert({
        ['<S-k>'] = cmp.mapping.scroll_docs(-4),
        ['<S-j>'] = cmp.mapping.scroll_docs(4),
        ['<C-space>'] = cmp.mapping.complete(),
        ['<tab>'] = cmp.mapping.confirm(),
      }),
      sources = cmp.config.sources({
        { name = 'nvim_lsp' },
      }, {
        {
          name = 'buffer',
          option = {
            get_bufnrs = function()
              return vim.api.nvim_list_bufs()
            end
          },
        },
        { name = 'path' },
      }),
      formatting = {
        format = require'lspkind'.cmp_format(),
      },
    }
  '';

  config.programs.ddd.neovim.plugins = with pkgs.ddd.vimPlugins; [
    cmp
    cmp-buffer
    cmp-luasnip
    cmp-nvim-lsp
    cmp-path
    lspkind
    luasnip
  ];
}
