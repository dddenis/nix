local typescript = require("config.typescript")

return {
    -- Where the workspace installs TypeScript 7+, tsc serves it instead.
    root_dir = function(bufnr, on_dir)
        local root = typescript.root(bufnr)
        if root and not typescript.tsgo(root) then
            on_dir(root)
        end
    end,
    init_options = {
        preferences = {
            importModuleSpecifierPreference = "project-relative",
        },
    },
}
