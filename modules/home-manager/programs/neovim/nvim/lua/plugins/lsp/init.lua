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
            vim.lsp.set_log_level("off")

            local base_on_attach = {}

            vim.api.nvim_create_autocmd("LspAttach", {
                callback = function(args)
                    local client = vim.lsp.get_client_by_id(args.data.client_id)
                    local client_on_attach = base_on_attach[client.name]
                    if client_on_attach then
                        client_on_attach(client, args.buf)
                    end
                    require("plugins.lsp.keymaps").on_attach(client, args.buf)
                end,
            })

            local capabilities = require("cmp_nvim_lsp").default_capabilities()

            for server_name, server_opts in pairs(opts.servers) do
                server_opts = vim.tbl_deep_extend("force", {
                    capabilities = vim.deepcopy(capabilities),
                }, server_opts or {})

                local server_on_attach = vim.lsp.config[server_name].on_attach
                if server_on_attach then
                    base_on_attach[server_name] = server_on_attach
                end

                vim.lsp.config(server_name, server_opts)
                vim.lsp.enable(server_name)
            end
        end,
    },
    {
        "nvimtools/none-ls.nvim",
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
