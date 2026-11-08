-- ---------------------------------------------------------------------------
-- LSP auto-enable
-- ---------------------------------------------------------------------------
-- Ensures defaults from `lsp/asciidoc.lua` (root_markers, filetypes, cmd) are
-- applied without the user needing to call `vim.lsp.enable("asciidoc")` from
-- their own config. Calling it from here is the only race-free spot when the
-- plugin is lazy-loaded on `ft = "asciidoc"`: by the time this file runs, the
-- plugin is on `runtimepath`, so `lsp/asciidoc.lua` is discoverable, and
-- `vim.lsp.enable` retroactively starts a client for the already-open buffer
-- that triggered the load.
do
    local ok, config = pcall(require, "asciidoc.config")
    if ok and config.lsp and config.lsp.enable ~= false then
        vim.lsp.enable("asciidoc")
    end
end

vim.api.nvim_create_user_command("AsciidocDebug", function()
    require("asciidoc.debug").run()
end, { desc = "Show how asciidoc-lsp resolves the cursor position" })

-- Treesitter Grammar Registration for cathaysia dual-grammar
-- (asciidoc + asciidoc_inline)
--
-- Why User TSUpdate: nvim-treesitter's reload_parsers() does:
--   1. package.loaded['nvim-treesitter.parsers'] = nil  (cache reset)
--   2. parsers = require('nvim-treesitter.parsers')      (fresh table)
--   3. vim.api.nvim_exec_autocmds('User', { pattern = 'TSUpdate' })  (hook)
-- Our callback runs at step 3, mutating the fresh table BEFORE install/config uses it.

-- Language registration MUST happen before the autocmd so Neovim maps
-- filetype "asciidoc" -> parser "asciidoc" immediately.
vim.treesitter.language.register("asciidoc", "asciidoc")

-- Guard: nvim-treesitter is optional
local has_ts, _ = pcall(require, "nvim-treesitter")
if not has_ts then
    return
end

vim.api.nvim_create_autocmd("User", {
    pattern = "TSUpdate",
    callback = function()
        local config = require("asciidoc.config")
        local parsers = require("nvim-treesitter.parsers")

        local upstream = {
            url = "https://github.com/seflue/tree-sitter-asciidoc",
            branch = "develop",
        }

        local adoc_override = config.treesitter.asciidoc or {}
        parsers.asciidoc = {
            install_info = {
                url = adoc_override.url or upstream.url,
                branch = adoc_override.branch or upstream.branch,
                location = "tree-sitter-asciidoc",
            },
            filetype = "asciidoc",
            requires = { "asciidoc_inline" },
            tier = 2,
        }

        local inline_override = config.treesitter.asciidoc_inline or {}
        parsers.asciidoc_inline = {
            install_info = {
                url = inline_override.url or upstream.url,
                branch = inline_override.branch or upstream.branch,
                location = "tree-sitter-asciidoc_inline",
            },
            tier = 2,
        }

        -- Auto-install both parsers (asciidoc + asciidoc_inline) when user opted in
        if config.treesitter.auto_install then
            vim.schedule(function()
                local install_ok, install = pcall(require, "nvim-treesitter.install")
                if install_ok then
                    install.ensure_installed({ "asciidoc", "asciidoc_inline" })
                end
            end)
        end
    end,
})
