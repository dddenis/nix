return {
    {
        "neovim/nvim-lspconfig",
        opts = {
            servers = {
                clojure_lsp = {},
            },
        },
    },
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
        end,
    },
    {
        "PaterJason/cmp-conjure",
        lazy = true,
        config = function()
            local cmp = require("cmp")
            local config = cmp.get_config()
            table.insert(config.sources, { name = "conjure" })
            return cmp.setup(config)
        end,
    },
}
