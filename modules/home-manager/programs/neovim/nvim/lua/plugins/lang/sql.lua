return {
    {
        "jose-elias-alvarez/null-ls.nvim",
        opts = function(_, opts)
            local builtins = require("null-ls").builtins
            table.insert(opts.sources, builtins.formatting.sql_formatter)
        end,
    },
}
