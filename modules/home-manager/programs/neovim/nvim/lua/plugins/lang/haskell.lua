return {
    "neovim/nvim-lspconfig",
    opts = {
        servers = {
            hls = {
                cmd = { "haskell-language-server", "--lsp" },
            },
        },
    },
}
