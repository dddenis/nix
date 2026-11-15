local function builtin(name, opts)
    return function()
        require("telescope.builtin")[name](opts)
    end
end

local function grep(opts)
    require("telescope").extensions.live_grep_args.live_grep_args(opts)
end

local function grep_word(opts)
    local word = vim.fn.expand("<cword>")
    opts = vim.tbl_extend("force", opts or {}, {
        default_text = vim.trim(require("telescope-live-grep-args.helpers").quote(word)) .. " -F ",
    })
    grep(opts)
end

local function with_buffer_cwd(fn)
    return function()
        fn({ cwd = require("telescope.utils").buffer_dir() })
    end
end

return {
    {
        "nvim-telescope/telescope.nvim",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "nvim-telescope/telescope-live-grep-args.nvim",
            { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
        },
        cmd = "Telescope",
        keys = {
            {
                "<leader><leader>",
                builtin("find_files", {
                    find_command = { "fd", "--type", "f", "--color", "never", "--hidden" },
                }),
                desc = "Find Files",
            },
            { "<leader>,", builtin("buffers"), desc = "Buffers" },
            { "<leader>fr", builtin("oldfiles"), desc = "Recent Files" },
            { "<leader>/", grep, desc = "Grep Files (root)" },
            { "<leader>s.", with_buffer_cwd(grep), desc = "Grep Files (cwd)" },
            { "<leader>sw", grep_word, desc = "Grep Word (root)" },
            { "<leader>sW", with_buffer_cwd(grep_word), desc = "Grep Word (cwd)" },
            { "<leader>'", builtin("resume"), desc = "Resume Search" },
        },
        opts = function()
            local lga_actions = require("telescope-live-grep-args.actions")

            return {
                defaults = {
                    dynamic_preview_title = true,
                    layout_strategy = "vertical",
                    layout_config = {
                        vertical = {
                            preview_height = 0.7,
                        },
                    },
                    mappings = {
                        n = {
                            ["q"] = "close",
                        },
                    },
                    vimgrep_arguments = {
                        "rg",
                        "--color=never",
                        "--no-heading",
                        "--with-filename",
                        "--line-number",
                        "--column",
                        "--smart-case",
                        "--hidden",
                    },
                },

                extensions = {
                    live_grep_args = {
                        mappings = {
                            i = {
                                ["<C-k>"] = lga_actions.quote_prompt(),
                                ["<C-i>"] = lga_actions.quote_prompt({ postfix = " --iglob " }),
                            },
                        },
                    },
                },
            }
        end,
        config = function(_, opts)
            local telescope = require("telescope")
            telescope.setup(opts)
            telescope.load_extension("fzf")
            telescope.load_extension("live_grep_args")
        end,
    },
}
