-- Minimal init for the test runner, its child processes and `just fixture`.
-- Loads only this plugin (and mini.nvim for the runner), never a user config.
--
-- ASCIIDOC_LSP_CMD: path to the asciidoc-lsp binary under test; defaults to
-- `asciidoc-lsp` on PATH.

local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.g.asciidoc_nvim_root = root

vim.opt.runtimepath:prepend(root)
package.path = root .. "/tests/?.lua;" .. package.path
vim.opt.runtimepath:append(root .. "/deps/mini.nvim")
vim.opt.runtimepath:append(root .. "/deps/site")
vim.opt.swapfile = false

local lsp_cmd = vim.env.ASCIIDOC_LSP_CMD
if lsp_cmd and lsp_cmd ~= "" then
    vim.lsp.config("asciidoc", { cmd = { lsp_cmd } })
end

if #vim.api.nvim_list_uis() == 0 and pcall(require, "mini.test") then
    require("mini.test").setup()
end
