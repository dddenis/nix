local map = vim.keymap.set

map("n", "<esc>", "<cmd>nohlsearch<cr>", { desc = "Clear Search" })

map("n", "j", "v:count == 0 ? 'gj' : 'j'", { expr = true })
map("n", "k", "v:count == 0 ? 'gk' : 'k'", { expr = true })

map("n", "<s-up>", "<cmd>resize +2<cr>", { desc = "Increase window height" })
map("n", "<s-down>", "<cmd>resize -2<cr>", { desc = "Decrease window height" })
map("n", "<s-left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease window width" })
map("n", "<s-right>", "<cmd>vertical resize +2<cr>", { desc = "Increase window width" })

map("n", "<leader>`", "<cmd>b#<cr>", { desc = "Toggle Buffer" })
map("n", "<leader>fs", "<cmd>w<cr>", { desc = "Save File" })

map("n", "<leader>dw", "<cmd>windo diffthis<cr>", { desc = "Diff Windows" })
map("n", "<leader>do", "<cmd>diffoff!<cr>", { desc = "Exit Diff" })

map("x", "g<C-i>", "g<C-a>", { desc = "Increment visual selection" })
map("x", "p", "P", { desc = "Paste without replacing register" })

local function copy_to_clipboard(fn)
    return function()
        vim.fn.setreg("+", fn())
    end
end
local function get_file_path()
    return vim.fn.expand("%:.")
end
local function get_file_dirname()
    return vim.fn.fnamemodify(get_file_path(), ":h")
end
local function get_file_basename()
    return vim.fn.fnamemodify(get_file_path(), ":t")
end
map("n", "<leader>yp", copy_to_clipboard(get_file_path), { desc = "Yank file path" })
map("n", "<leader>yd", copy_to_clipboard(get_file_dirname), { desc = "Yank file dirname" })
map("n", "<leader>yb", copy_to_clipboard(get_file_basename), { desc = "Yank file basename" })

map("n", "<leader>1", "1gt", { desc = "Go to tab #1" })
map("n", "<leader>2", "2gt", { desc = "Go to tab #2" })
map("n", "<leader>3", "3gt", { desc = "Go to tab #3" })
map("n", "<leader>4", "4gt", { desc = "Go to tab #4" })
map("n", "<leader>5", "5gt", { desc = "Go to tab #5" })
map("n", "<leader>6", "6gt", { desc = "Go to tab #6" })
map("n", "<leader>7", "7gt", { desc = "Go to tab #7" })
map("n", "<leader>8", "8gt", { desc = "Go to tab #8" })
map("n", "<leader>9", "9gt", { desc = "Go to tab #9" })
map("n", "<leader>0", ":tablast<cr>", { desc = "Go to last tab" })
