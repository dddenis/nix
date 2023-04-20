return {
    "tpope/vim-abolish",
    "tpope/vim-repeat",
    "tpope/vim-sleuth",
    "tpope/vim-surround",
    "tpope/vim-unimpaired",
    { "windwp/nvim-autopairs", opts = {} },
    {
        "numToStr/Comment.nvim",
        dependencies = {
            "JoosepAlviste/nvim-ts-context-commentstring",
        },
        keys = {
            { "gc", mode = { "n", "v" } },
            { "gb", mode = { "n", "v" } },
        },
        config = function()
            require("Comment").setup({
                pre_hook = require("ts_context_commentstring.integrations.comment_nvim").create_pre_hook(),
                ignore = "^$",
            })
        end,
    },
    {
        "christoomey/vim-tmux-navigator",
        config = function()
            vim.g.tmux_navigator_disable_when_zoomed = 1
        end,
    },
    {
        "voldikss/vim-floaterm",
        keys = {
            { "<leader>.", "<cmd>FloatermNew lf<cr>" },
        },
        config = function()
            vim.g.floaterm_opener = "edit"
        end,
    },
    {
        "famiu/bufdelete.nvim",
        keys = {
            { "<leader>bd", "<cmd>Bdelete<cr>", desc = "Delete Buffer" },
            { "<leader>bD", "<cmd>Bdelete!<cr>", desc = "Delete Buffer (force)" },
        },
    },
    {
        "haya14busa/vim-asterisk",
        keys = {
            { "*", "<plug>(asterisk-z*)", mode = "" },
            { "#", "<plug>(asterisk-z#)", mode = "" },
            { "g*", "<plug>(asterisk-gz*)", mode = "" },
            { "g#", "<plug>(asterisk-gz#)", mode = "" },
        },
    },
    {
        "ggandor/leap.nvim",
        keys = {
            { "s", mode = { "n", "x", "o" }, desc = "Leap forward to" },
            { "S", mode = { "n", "x", "o" }, desc = "Leap backward to" },
            { "gs", mode = { "n", "x", "o" }, desc = "Leap from windows" },
        },
        config = function()
            require("leap").add_default_mappings()
        end,
    },
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        dependencies = {
            { "nvim-treesitter/nvim-treesitter-context", opts = {} },
        },
        event = { "BufReadPost", "BufNewFile" },
        main = "nvim-treesitter.configs",
        opts = {
            auto_install = true,
            highlight = {
                enable = true,
            },
            indent = {
                enable = true,
            },
            context_commentstring = {
                enable = true,
                enable_autocmd = false,
            },
        },
    },
}
