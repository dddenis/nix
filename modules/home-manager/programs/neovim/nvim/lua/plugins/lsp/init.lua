vim.diagnostic.config({
    float = {
        source = true,
    },
})

return {
    {
        "neovim/nvim-lspconfig",
        event = { "BufReadPre", "BufNewFile" },
        dependencies = {
            "hrsh7th/cmp-nvim-lsp",
            { "ray-x/lsp_signature.nvim", opts = {} },
        },
        opts = {
            servers = {},
        },
        config = function(_, opts)
            vim.api.nvim_create_autocmd("LspAttach", {
                callback = function(args)
                    local client = vim.lsp.get_client_by_id(args.data.client_id)
                    require("plugins.lsp.keymaps").on_attach(client, args.buf)
                end,
            })

            local capabilities = require("cmp_nvim_lsp").default_capabilities()

            for server_name, server_opts in pairs(opts.servers) do
                server_opts = vim.tbl_deep_extend("force", {
                    capabilities = vim.deepcopy(capabilities),
                }, server_opts or {})

                require("lspconfig")[server_name].setup(server_opts)
            end
        end,
    },
    {
        "jose-elias-alvarez/null-ls.nvim",
        event = { "BufReadPre", "BufNewFile" },
        opts = function()
            return {
                root_dir = require("null-ls.utils").root_pattern(".git"),
                diagnostics_format = "[#{s}:#{c}] #{m}",
                sources = {},
            }
        end,
    },
}
