return {
    cmd = { "haskell-language-server", "--lsp" },
    settings = {
        haskell = {
            formattingProvider = "fourmolu",
        },
    },
}
