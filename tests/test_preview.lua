local helpers = require("helpers")
local expect = MiniTest.expect

local child = helpers.new_child()

local T = MiniTest.new_set({
    hooks = {
        pre_case = child.setup,
        post_once = child.stop,
    },
})

-- Record every cursorMoved the client sends and keep the browser closed.
local function stub_client()
    child.lua([[
        _G.opened = {}
        vim.ui.open = function(url)
            table.insert(_G.opened, url)
            return {}, nil
        end
        _G.moved = {}
        local client = vim.lsp.get_clients({ bufnr = 0, name = "asciidoc" })[1]
        local notify = client.notify
        client.notify = function(self, method, params)
            if method == "asciidoc/cursorMoved" then
                table.insert(_G.moved, params)
            end
            return notify(self, method, params)
        end
    ]])
end

T["sends no cursor position before the preview is open"] = function()
    helpers.edit_with_lsp(child, "tests/fixtures/basic.adoc")
    stub_client()
    child.api.nvim_win_set_cursor(0, { 3, 0 })
    child.cmd("doautocmd CursorMoved")
    child.lua("vim.wait(300)")
    expect.equality(child.lua_get("#_G.moved"), 0)
end

T["sends while the cursor keeps moving"] = function()
    helpers.edit_with_lsp(child, "tests/fixtures/basic.adoc")
    stub_client()
    child.cmd("AsciidocPreview")
    expect.equality(child.lua_get("vim.wait(10000, function() return #_G.opened > 0 end, 20)"), true)
    child.lua("vim.wait(300)")
    -- Move every 30 ms for 450 ms; a debounce would send nothing until the end.
    child.lua([[
        _G.moved = {}
        _G.sent_during = 0
        for i = 1, 15 do
            vim.api.nvim_win_set_cursor(0, { (i % 3) + 1, 0 })
            vim.api.nvim_exec_autocmds("CursorMoved", {})
            vim.wait(30)
        end
        _G.sent_during = #_G.moved
    ]])
    expect.equality(child.lua_get("_G.sent_during > 0"), true)
end

T["opens the URL and then follows the cursor"] = function()
    helpers.edit_with_lsp(child, "tests/fixtures/basic.adoc")
    stub_client()
    child.cmd("AsciidocPreview")
    expect.equality(child.lua_get("vim.wait(10000, function() return #_G.opened > 0 end, 20)"), true)
    expect.equality(child.lua_get("_G.opened[1]:match('^http://127%.0%.0%.1:%d+/') ~= nil"), true)
    child.lua("vim.wait(300)")
    child.lua("_G.moved = {}")
    child.api.nvim_win_set_cursor(0, { 3, 0 })
    child.cmd("doautocmd CursorMoved")
    child.lua("vim.wait(500, function() return #_G.moved > 0 end, 20)")
    local last = child.lua_get("_G.moved[#_G.moved]")
    expect.equality(last.line, 2)
    expect.equality(last.uri, child.lua_get("vim.uri_from_bufnr(0)"))
end

return T
