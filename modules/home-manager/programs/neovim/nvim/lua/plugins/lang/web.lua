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
                svelte = {
                    on_attach = function(client)
                        vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "TextChangedP" }, {
                            pattern = { "*.js", "*.ts" },
                            group = vim.api.nvim_create_augroup("svelte_ondidchangetsorjsfile", { clear = true }),
                            callback = function(ctx)
                                client.notify("$/onDidChangeTsOrJsFile", {
                                    uri = ctx.file,
                                    changes = {
                                        {
                                            text = table.concat(
                                                vim.api.nvim_buf_get_lines(ctx.buf, 0, -1, false),
                                                "\n"
                                            ),
                                        },
                                    },
                                })
                            end,
                        })
                    end,
                },
                ts_ls = {
                    init_options = {
                        preferences = {
                            importModuleSpecifierPreference = "project-relative",
                        },
                    },

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
        "nvimtools/none-ls.nvim",
        opts = function(_, opts)
            local builtins = require("null-ls").builtins
            table.insert(opts.sources, builtins.formatting.prettier)
        end,
    },
}
