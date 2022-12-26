{ neovimPkgs, ... }:

{
  config.programs.ddd.neovim.lsp.format.exclude = [
    "tsserver"
  ];

  config.programs.ddd.neovim.lsp.null-ls.sources = [
    "require'null-ls'.builtins.formatting.prettier"
  ];

  config.programs.ddd.neovim.lsp.client.tsserver = {
    onAttach = ''
      local function organize_imports()
        vim.lsp.buf.execute_command({
          command = '_typescript.organizeImports',
          arguments = { vim.api.nvim_buf_get_name(0) },
        })
      end

      map('n', '<leader>ci', organize_imports, { desc = 'Organize Imports' })
    '';
  };

  config.programs.ddd.neovim.lsp.client.eslint = {
    onAttach = ''
      map('n', '<leader>ce', ':EslintFixAll<cr>')
    '';
  };

  config.programs.ddd.neovim.packages = with neovimPkgs; [
    nodePackages.prettier
    nodePackages.typescript-language-server
    nodePackages.vscode-langservers-extracted
  ];
}
