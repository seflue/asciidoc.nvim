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

vim.api.nvim_create_user_command("AsciidocPreview", function(opts)
    require("asciidoc.preview").open(opts.fargs[1])
end, {
    nargs = "?",
    complete = function(arg_lead)
        return require("asciidoc.preview").complete_modes(arg_lead)
    end,
    desc = "Open the AsciiDoc preview in the browser and make it follow the cursor",
})

vim.api.nvim_create_user_command("AsciidocPreviewStop", function()
    require("asciidoc.preview").stop()
end, { desc = "Stop the AsciiDoc preview from following the cursor" })

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

-- Before any FileType autocmd compiles the queries for the buffer that
-- loaded the plugin: an outdated parser must not keep the buffer from being
-- set up, or the TSUpdate registration below from being reached.
require("asciidoc.grammar").guard_queries()

-- Guard: nvim-treesitter is optional
local has_ts, _ = pcall(require, "nvim-treesitter")
if not has_ts then
    return
end

vim.api.nvim_create_autocmd("User", {
    pattern = "TSUpdate",
    callback = function()
        local grammar = require("asciidoc.grammar")
        local parsers = require("nvim-treesitter.parsers")

        parsers.asciidoc = {
            install_info = grammar.install_info("asciidoc"),
            filetype = "asciidoc",
            requires = { "asciidoc_inline" },
            tier = 2,
        }

        parsers.asciidoc_inline = {
            install_info = grammar.install_info("asciidoc_inline"),
            tier = 2,
        }
    end,
})

-- Auto-install both parsers when the user opted in, at load and not in the
-- TSUpdate callback: nvim-treesitter fires TSUpdate on every install and
-- update, so installing from there would loop.
if require("asciidoc.config").treesitter.auto_install then
    vim.schedule(function()
        require("asciidoc.grammar").auto_install()
    end)
end
