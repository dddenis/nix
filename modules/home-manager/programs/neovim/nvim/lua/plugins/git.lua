return {
    "tpope/vim-fugitive",
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
                local gs = package.loaded.gitsigns
                local map = MapWith({ buffer = buffer })

                map("n", "]c", function()
                    if vim.wo.diff then
                        return "]c"
                    end
                    vim.schedule(function()
                        gs.next_hunk()
                    end)
                    return "<Ignore>"
                end, { expr = true })

                map("n", "[c", function()
                    if vim.wo.diff then
                        return "[c"
                    end
                    vim.schedule(function()
                        gs.prev_hunk()
                    end)
                    return "<Ignore>"
                end, { expr = true })

                map({ "n", "v" }, "<leader>gr", gs.reset_hunk)
                map({ "n", "v" }, "<leader>gs", gs.stage_hunk)
                map("n", "<leader>gu", gs.undo_stage_hunk)
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
                map("n", "<leader>gtd", gs.toggle_deleted)

                map({ "o", "x" }, "ih", "<cmd><C-u>Gitsigns select_hunk<cr>")
            end,
        },
    },
    {
        "sindrets/diffview.nvim",
        opts = {},
    },
}
