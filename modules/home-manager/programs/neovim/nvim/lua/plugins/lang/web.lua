return {
    {
        "neovim/nvim-lspconfig",
        opts = {
            servers = {
                astro = {},
                eslint = {
                    on_attach = function()
                        vim.keymap.set("n", "<leader>ce", "<cmd>EslintFixAll<cr>", { desc = "Fix All" })
                    end,
                },
                tsserver = {
                    on_attach = function()
                        local function organize_imports()
                            vim.lsp.buf.execute_command({
                                command = "_typescript.organizeImports",
                                arguments = { vim.api.nvim_buf_get_name(0) },
                            })
                        end

                        vim.keymap.set("n", "<leader>ci", organize_imports, { desc = "Organize Imports" })
                    end,
                },
            },
        },
    },
    {
        "jose-elias-alvarez/null-ls.nvim",
        opts = function(_, opts)
            local builtins = require("null-ls").builtins
            table.insert(opts.sources, builtins.formatting.prettier)
        end,
    },
}
