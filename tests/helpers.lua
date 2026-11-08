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

--- Return the sorted `{ start_row, start_col, end_row, end_col }` ranges the
--- asciidoc `query_name` query yields for `capture` in the child's buffer. A
--- quantified capture spans from its first to its last node, as
--- nvim-treesitter-textobjects resolves it.
function Helpers.capture_ranges(child, query_name, capture)
    return child.lua_get(
        [[(function(query_name, capture)
        local root = vim.treesitter.get_parser(0):parse()[1]:root()
        local query = vim.treesitter.query.get("asciidoc", query_name)
        local ranges = {}
        for _, match in query:iter_matches(root, 0) do
            for id, nodes in pairs(match) do
                if query.captures[id] == capture then
                    local srow, scol = nodes[1]:range()
                    local _, _, erow, ecol = nodes[#nodes]:range()
                    ranges[#ranges + 1] = { srow, scol, erow, ecol }
                end
            end
        end
        table.sort(ranges, function(a, b)
            for i = 1, 4 do
                if a[i] ~= b[i] then
                    return a[i] < b[i]
                end
            end
            return false
        end)
        return ranges
    end)(...)]],
        { query_name, capture }
    )
end

return Helpers
