return {
    "tpope/vim-abolish",
    "tpope/vim-repeat",
    "tpope/vim-sleuth",
    "tpope/vim-surround",
    "tpope/vim-unimpaired",
    { "windwp/nvim-autopairs", opts = {} },
    {
        -- context-aware commentstring (e.g. JSX) for the built-in gc/gcc
        "JoosepAlviste/nvim-ts-context-commentstring",
        lazy = true,
        opts = {
            enable_autocmd = false,
        },
        init = function()
            local get_option = vim.filetype.get_option
            ---@diagnostic disable-next-line: duplicate-set-field
            vim.filetype.get_option = function(filetype, option)
                return option == "commentstring"
                        and require("ts_context_commentstring.internal").calculate_commentstring()
                    or get_option(filetype, option)
            end
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
            -- enable treesitter highlighting and indentation
            local function start(buf)
                vim.treesitter.start(buf)
                vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
            end

            -- buffers waiting for a parser that is being installed, by language
            local pending = {} ---@type table<string, integer[]>

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
                    if vim.list_contains(require("nvim-treesitter.config").get_installed(), lang) then
                        start(args.buf)
                        return
                    end
                    -- auto-install missing parsers, once per language
                    if pending[lang] then
                        table.insert(pending[lang], args.buf)
                        return
                    end
                    pending[lang] = { args.buf }
                    require("nvim-treesitter").install({ lang }):await(vim.schedule_wrap(function()
                        local bufs = pending[lang]
                        pending[lang] = nil
                        if not vim.treesitter.language.add(lang) then
                            return
                        end
                        for _, buf in ipairs(bufs) do
                            local ft = vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype
                            if ft and vim.treesitter.language.get_lang(ft) == lang then
                                start(buf)
                            end
                        end
                    end))
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
