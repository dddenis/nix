return {
    {
        "saghen/blink.cmp",
        version = "1.*",
        opts = {
            keymap = {
                preset = "default",
                ["<Tab>"] = { "select_and_accept", "snippet_forward", "fallback" },
                ["<S-Tab>"] = { "snippet_backward", "fallback" },
                ["<C-k>"] = { "scroll_documentation_up", "fallback" },
                ["<C-j>"] = { "scroll_documentation_down", "fallback" },
            },
            completion = {
                accept = {
                    auto_brackets = { enabled = false },
                },
                documentation = { auto_show = true },
                menu = {
                    draw = {
                        columns = {
                            { "label", "label_description", gap = 1 },
                            { "kind_icon", "kind", gap = 1 },
                        },
                    },
                },
            },
            signature = { enabled = true },
            -- keep the native wildmenu on the command line
            cmdline = { enabled = false },
            fuzzy = {
                -- exact matches first, so short snippet triggers win
                sorts = { "exact", "score", "sort_text" },
            },
            sources = {
                providers = {
                    buffer = {
                        opts = {
                            get_bufnrs = vim.api.nvim_list_bufs,
                        },
                    },
                },
            },
        },
    },
}
