return {
    {
        "stevearc/conform.nvim",
        cmd = "ConformInfo",
        keys = {
            {
                "<leader>cf",
                function()
                    require("conform").format()
                end,
                mode = { "n", "v" },
                desc = "Format",
            },
        },
        opts = function()
            local formatters_by_ft = {
                bats = { "shfmt" },
                lua = { "stylua" },
                luau = { "stylua" },
                sh = { "shellharden", "shfmt" },
                sql = { "sql_formatter" },
            }

            for _, ft in ipairs({
                "astro",
                "css",
                "graphql",
                "handlebars",
                "html",
                "htmlangular",
                "javascript",
                "javascriptreact",
                "json",
                "json5",
                "jsonc",
                "less",
                "markdown",
                "markdown.mdx",
                "scss",
                "svelte",
                "typescript",
                "typescriptreact",
                "vue",
                "yaml",
            }) do
                formatters_by_ft[ft] = { "prettier" }
            end

            return {
                formatters_by_ft = formatters_by_ft,
                -- use the language server when no formatter is configured
                default_format_opts = { lsp_format = "fallback" },
            }
        end,
    },
}
