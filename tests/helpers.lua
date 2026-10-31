-- Shared helpers for tests that drive a child Neovim with asciidoc-lsp attached.

local Helpers = {}

local root = vim.g.asciidoc_nvim_root

--- Start a child Neovim with the minimal init.
function Helpers.new_child()
    local child = MiniTest.new_child_neovim()
    child.setup = function()
        child.restart({ "-u", root .. "/tests/minimal_init.lua" })
    end
    return child
end

--- Open `path` (relative to the plugin root) in the child and wait until
--- asciidoc-lsp has attached and finished initializing.
function Helpers.edit_with_lsp(child, path)
    child.cmd("edit " .. root .. "/" .. path)
    local attached = child.lua_get([[vim.wait(10000, function()
        local client = vim.lsp.get_clients({ bufnr = 0, name = "asciidoc" })[1]
        return client ~= nil and client.initialized
    end, 20)]])
    if not attached then
        local cmd = child.lua_get([[vim.lsp.config.asciidoc.cmd]])
        error("asciidoc-lsp did not attach (cmd: " .. vim.inspect(cmd) .. ")")
    end
end

return Helpers
