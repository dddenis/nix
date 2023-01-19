{ neovimPkgs, ... }:

{
  config.programs.ddd.neovim.lsp.client.gopls = {
    onAttach = ''
      local function organize_imports()
        local params = vim.lsp.util.make_range_params()
        params.context = { only = { "source.organizeImports" } }
        local result = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, 1000)
        for cid, res in pairs(result or {}) do
          for _, r in pairs(res.result or {}) do
            if r.edit then
              local enc = (vim.lsp.get_client_by_id(cid) or {}).offset_encoding or "utf-16"
              vim.lsp.util.apply_workspace_edit(r.edit, enc)
            end
          end
        end
      end

      map('n', '<leader>ci', organize_imports, { desc = 'Organize Imports' })
    '';
  };

  config.programs.ddd.neovim.packages = with neovimPkgs; [
    gopls
  ];
}
