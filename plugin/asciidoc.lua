-- Treesitter Grammar Registration for cathaysia dual-grammar
-- (asciidoc + asciidoc_inline)
--
-- Why User TSUpdate: nvim-treesitter's reload_parsers() does:
--   1. package.loaded['nvim-treesitter.parsers'] = nil  (cache reset)
--   2. parsers = require('nvim-treesitter.parsers')      (fresh table)
--   3. vim.api.nvim_exec_autocmds('User', { pattern = 'TSUpdate' })  (hook)
-- Our callback runs at step 3, mutating the fresh table BEFORE install/config uses it.

-- Default highlights for custom capture groups — user/colorscheme can override
vim.api.nvim_set_hl(0, "@markup.mark.asciidoc_inline", {
    default = true,
    bg = "#3a3a2a",
    italic = true,
})

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
            url = "https://github.com/cathaysia/tree-sitter-asciidoc",
            branch = "master",
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
