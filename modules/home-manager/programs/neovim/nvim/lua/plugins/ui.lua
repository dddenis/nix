return {
    {
        "sainnhe/gruvbox-material",
        priority = 1000,
        config = function()
            vim.cmd("colorscheme gruvbox-material")
        end,
    },
    {
        "nvim-lualine/lualine.nvim",
        opts = {
            sections = {
                lualine_b = { "diff", "diagnostics" },
            },
        },
        init = function()
            vim.opt.showmode = false
        end,
    },
    {
        "stevearc/dressing.nvim",
        lazy = true,
        dependencies = {
            "nvim-telescope/telescope.nvim",
        },
        init = function()
            ---@diagnostic disable-next-line: duplicate-set-field
            vim.ui.select = function(...)
                require("lazy").load({ plugins = { "dressing.nvim" } })
                return vim.ui.select(...)
            end
            ---@diagnostic disable-next-line: duplicate-set-field
            vim.ui.input = function(...)
                require("lazy").load({ plugins = { "dressing.nvim" } })
                return vim.ui.input(...)
            end
        end,
        opts = function()
            return {
                input = {
                    insert_only = false,
                },
                select = {
                    telescope = require("telescope.themes").get_dropdown({
                        initial_mode = "normal",
                    }),
                },
            }
        end,
    },
}
