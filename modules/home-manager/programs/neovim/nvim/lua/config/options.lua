vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.clipboard = "unnamedplus"
vim.opt.termguicolors = true

vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.undofile = true

vim.opt.scrolloff = 5
vim.opt.sidescrolloff = 5

vim.opt.signcolumn = "yes"
vim.opt.number = true
vim.opt.relativenumber = true

vim.opt.list = true
vim.opt.listchars = {
    tab = "▸-",
    trail = "·",
    extends = "›",
    precedes = "‹",
    nbsp = "␣",
}

vim.opt.expandtab = true
vim.opt.tabstop = 4
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2

vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.wildmode = { "longest:full", "full" }

vim.opt.foldenable = false
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"

vim.opt.matchpairs:append("<:>")
