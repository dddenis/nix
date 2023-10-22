return {
    "neovim/nvim-lspconfig",
    opts = {
        servers = {
            elixirls = {
                cmd = { "elixir-ls" },
            },
        },
    },
}
