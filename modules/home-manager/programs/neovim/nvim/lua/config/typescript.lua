-- TypeScript 7 (tsgo) has its own language server, which lspconfig runs as `tsc`.
-- Use it in workspaces that install TypeScript 7+ and ts_ls everywhere else, so
-- language features match the TypeScript the workspace compiles with.

local M = {}

local lockfiles = { "package-lock.json", "yarn.lock", "pnpm-lock.yaml", "bun.lockb", "bun.lock" }

--- Project root as lspconfig's ts_ls and tsc find it: the nearest lockfile, else
--- .git, else the cwd. nil inside a Deno project.
---@param bufnr integer
---@return string?
function M.root(bufnr)
    local project = vim.fs.root(bufnr, { lockfiles, ".git" })
    local deno_lock = vim.fs.root(bufnr, { "deno.lock" })
    if deno_lock and (not project or #deno_lock > #project) then
        return nil
    end
    local deno = vim.fs.root(bufnr, { "deno.json", "deno.jsonc" })
    if deno and (not project or #deno >= #project) then
        return nil
    end
    return project or vim.fn.getcwd()
end

local tsgo_bins = {} ---@type table<string, string|false>

--- The workspace's TypeScript 7+ binary, which serves `--lsp`, or nil without one.
--- Checked once per root: installing TypeScript 7 needs a restart to take effect.
---@param root string
---@return string?
function M.tsgo(root)
    if tsgo_bins[root] == nil then
        tsgo_bins[root] = false
        for _, name in ipairs({ "tsc", "tsgo" }) do
            local bin = vim.fs.joinpath(root, "node_modules", ".bin", name)
            if vim.fn.executable(bin) == 1 then
                local out = vim.system({ bin, "--version" }, { text = true }):wait(5000)
                local version = out.code == 0 and vim.version.parse(out.stdout or "") or nil
                if version and version.major >= 7 then
                    tsgo_bins[root] = bin
                    break
                end
            end
        end
    end
    return tsgo_bins[root] or nil
end

return M
