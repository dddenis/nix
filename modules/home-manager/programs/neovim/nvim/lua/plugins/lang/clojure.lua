return {
    {
        "Olical/conjure",
        ft = { "clojure" },
        lazy = true,
        dependencies = { "PaterJason/cmp-conjure" },
        init = function()
            vim.g["conjure#log#wrap"] = true
            vim.g["conjure#mapping#doc_word"] = false
            vim.g["conjure#client#clojure#nrepl#mapping#disconnect"] = false
            vim.g["conjure#client#clojure#nrepl#mapping#connect_port_file"] = false
            vim.g["conjure#client#clojure#nrepl#connection#auto_repl#enabled"] = false
        end,
    },
    {
        -- nvim-cmp source, used by blink.cmp through blink.compat
        "PaterJason/cmp-conjure",
        lazy = true,
        dependencies = {
            { "saghen/blink.compat", version = "2.*", opts = {} },
        },
    },
    {
        "saghen/blink.cmp",
        opts = {
            sources = {
                per_filetype = {
                    clojure = { inherit_defaults = true, "conjure" },
                },
                providers = {
                    conjure = { name = "conjure", module = "blink.compat.source" },
                },
            },
        },
    },
}
