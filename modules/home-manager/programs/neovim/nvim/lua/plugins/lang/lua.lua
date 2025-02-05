return {
    {
        "neovim/nvim-lspconfig",
        dependencies = {
            { "folke/neodev.nvim", opts = {} },
        },
        opts = {
            servers = {
                lua_ls = {
                    settings = {
                        Lua = {
                            format = {
                                enable = false,
                            },
                            telemetry = {
                                enable = false,
                            },
                            workspace = {
                                checkThirdParty = false,
                            },
                        },
                    },
                },
            },
        },
    },
    {
        "nvimtools/none-ls.nvim",
        opts = function(_, opts)
            local builtins = require("null-ls").builtins
            table.insert(opts.sources, builtins.formatting.stylua)
        end,
    },
}
