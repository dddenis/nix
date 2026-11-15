return {
    {
        "tpope/vim-fugitive",
        dependencies = {
            "tpope/vim-rhubarb",
        },
    },
    {
        "samoshkin/vim-mergetool",
        cmd = { "MergetoolStart" },
        keys = function()
            local function diff_guard(lhs, rhs)
                return {
                    lhs,
                    "&diff ? '" .. rhs .. "' : '" .. lhs .. "'",
                    expr = true,
                    replace_keycodes = false,
                }
            end

            return {
                { "<leader>gm", "<plug>(MergetoolToggle)" },
                diff_guard("<leader>gh", "<plug>(MergetoolDiffExchangeLeft)"),
                diff_guard("<leader>gl", "<plug>(MergetoolDiffExchangeRight)"),
                diff_guard("<leader>gj", "<plug>(MergetoolDiffExchangeDown)"),
                diff_guard("<leader>gk", "<plug>(MergetoolDiffExchangeUp)"),
            }
        end,
    },
    {
        "lewis6991/gitsigns.nvim",
        event = { "BufReadPre", "BufNewFile" },
        opts = {
            on_attach = function(buffer)
                local gs = require("gitsigns")
                local function map(mode, lhs, rhs)
                    vim.keymap.set(mode, lhs, rhs, { buffer = buffer })
                end

                map("n", "]c", function()
                    if vim.wo.diff then
                        vim.cmd.normal({ "]c", bang = true })
                    else
                        gs.nav_hunk("next")
                    end
                end)

                map("n", "[c", function()
                    if vim.wo.diff then
                        vim.cmd.normal({ "[c", bang = true })
                    else
                        gs.nav_hunk("prev")
                    end
                end)

                map({ "n", "v" }, "<leader>gr", ":Gitsigns reset_hunk<cr>")
                map({ "n", "v" }, "<leader>gs", ":Gitsigns stage_hunk<cr>")
                map("n", "<leader>gp", gs.preview_hunk)
                map("n", "<leader>gS", gs.stage_buffer)
                map("n", "<leader>gR", gs.reset_buffer)
                map("n", "<leader>gb", function()
                    gs.blame_line({ full = true })
                end)
                map("n", "<leader>gtb", gs.toggle_current_line_blame)
                map("n", "<leader>gd", gs.diffthis)
                map("n", "<leader>gD", function()
                    gs.diffthis("~")
                end)
                map("n", "<leader>gtd", gs.preview_hunk_inline)

                map({ "o", "x" }, "ih", gs.select_hunk)
            end,
        },
    },
    {
        "sindrets/diffview.nvim",
        opts = {},
    },
}
