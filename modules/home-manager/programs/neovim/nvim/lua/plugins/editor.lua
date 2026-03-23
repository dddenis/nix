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
        "JoosepAlviste/nvim-ts-context-commentstring",
        lazy = true,
        opts = {
            enable_autocmd = false,
        },
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
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        lazy = false,
        dependencies = {
            "nvim-treesitter/nvim-treesitter-textobjects",
            { "nvim-treesitter/nvim-treesitter-context", opts = { max_lines = 3 } },
        },
        config = function()
            vim.api.nvim_create_autocmd("FileType", {
                callback = function(args)
                    local lang = vim.treesitter.language.get_lang(args.match)
                    if not lang then
                        return
                    end
                    local parsers = require("nvim-treesitter.parsers")
                    if not parsers[lang] then
                        return
                    end
                    -- auto-install missing parsers
                    if not vim.list_contains(require("nvim-treesitter.config").get_installed(), lang) then
                        require("nvim-treesitter.install").install({ lang })
                        return
                    end
                    -- enable treesitter highlighting and indentation
                    vim.treesitter.start(args.buf)
                    vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
                end,
            })

            -- textobject keymaps (replaces old textobjects.select config)
            local select_textobject = function(query)
                return function()
                    require("nvim-treesitter-textobjects.select").select_textobject(query)
                end
            end
            for _, map in ipairs({
                { "af", "@function.outer" },
                { "if", "@function.inner" },
                { "ac", "@class.outer" },
                { "ic", "@class.inner" },
            }) do
                vim.keymap.set({ "x", "o" }, map[1], select_textobject(map[2]))
            end

            -- textobjects config (lookahead)
            require("nvim-treesitter-textobjects").setup({
                select = { lookahead = true },
            })
        end,
    },
}
