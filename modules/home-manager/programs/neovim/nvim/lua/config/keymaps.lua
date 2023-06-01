Map("n", "<esc>", "<cmd>nohlsearch<cr>", { desc = "Clear Search" })

Map("n", "j", "v:count == 0 ? 'gj' : 'j'", { expr = true })
Map("n", "k", "v:count == 0 ? 'gk' : 'k'", { expr = true })

Map("n", "<s-up>", "<cmd>resize +2<cr>", { desc = "Increase window height" })
Map("n", "<s-down>", "<cmd>resize -2<cr>", { desc = "Decrease window height" })
Map("n", "<s-left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease window width" })
Map("n", "<s-right>", "<cmd>vertical resize +2<cr>", { desc = "Increase window width" })

Map("n", "<leader>`", "<cmd>b#<cr>", { desc = "Toggle Buffer" })
Map("n", "<leader>fs", "<cmd>w<cr>", { desc = "Save File" })

Map("n", "<leader>dw", "<cmd>windo diffthis<cr>", { desc = "Diff Windows" })
Map("n", "<leader>do", "<cmd>diffoff!<cr>", { desc = "Exit Diff" })
