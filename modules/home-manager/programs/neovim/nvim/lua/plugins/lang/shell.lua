vim.filetype.add({
    filename = {
        [".env"] = "sh.dotenv",
    },
    pattern = {
        [".+%.env"] = "sh.dotenv",
        ["%.env%..+"] = "sh.dotenv",
    },
})

return {
    {
        "neovim/nvim-lspconfig",
        opts = {
            servers = {
                bashls = {},
            },
        },
    },
    {
        "nvimtools/none-ls.nvim",
        opts = function(_, opts)
            local builtins = require("null-ls").builtins
            table.insert(opts.sources, builtins.formatting.shellharden)
            table.insert(opts.sources, builtins.formatting.shfmt)
        end,
    },
}
