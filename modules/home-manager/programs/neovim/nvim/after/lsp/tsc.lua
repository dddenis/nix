local typescript = require("config.typescript")

-- Attach only where the workspace installs TypeScript 7+; ts_ls covers the rest.
-- lspconfig's root_dir would also take a tsc from $PATH and warns when none
-- qualifies, so it is replaced, along with the cmd that reads its binary cache.
return {
    cmd = function(dispatchers, config)
        return vim.lsp.rpc.start({ typescript.tsgo(config.root_dir), "--lsp", "--stdio" }, dispatchers)
    end,
    root_dir = function(bufnr, on_dir)
        local root = typescript.root(bufnr)
        if root and typescript.tsgo(root) then
            on_dir(root)
        end
    end,
    settings = {
        ["js/ts"] = {
            preferences = {
                importModuleSpecifier = "project-relative",
            },
        },
    },
}
