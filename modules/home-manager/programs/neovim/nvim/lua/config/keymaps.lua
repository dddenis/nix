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

Map("n", "<leader>1", "1gt", { desc = "Go to tab #1" })
Map("n", "<leader>2", "2gt", { desc = "Go to tab #2" })
Map("n", "<leader>3", "3gt", { desc = "Go to tab #3" })
Map("n", "<leader>4", "4gt", { desc = "Go to tab #4" })
Map("n", "<leader>5", "5gt", { desc = "Go to tab #5" })
Map("n", "<leader>6", "6gt", { desc = "Go to tab #6" })
Map("n", "<leader>7", "7gt", { desc = "Go to tab #7" })
Map("n", "<leader>8", "8gt", { desc = "Go to tab #8" })
Map("n", "<leader>9", "9gt", { desc = "Go to tab #9" })
Map("n", "<leader>0", ":tablast<cr>", { desc = "Go to last tab" })
