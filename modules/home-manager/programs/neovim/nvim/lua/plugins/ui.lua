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
        "folke/snacks.nvim",
        priority = 1000,
        lazy = false,
        opts = {
            -- vim.ui.input
            input = { enabled = true },
            -- vim.ui.select, opened on the list so j/k/<cr> work right away
            picker = {
                enabled = true,
                sources = {
                    select = { focus = "list" },
                },
            },
        },
        keys = {
            {
                "<leader>bd",
                function()
                    Snacks.bufdelete()
                end,
                desc = "Delete Buffer",
            },
            {
                "<leader>bD",
                function()
                    Snacks.bufdelete({ force = true })
                end,
                desc = "Delete Buffer (force)",
            },
        },
    },
}
