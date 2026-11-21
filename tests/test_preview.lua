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
        _G.open_fails = false
        vim.ui.open = function(url)
            table.insert(_G.opened, url)
            if _G.open_fails then
                return nil, "no browser"
            end
            return {}, nil
        end
        _G.moved = {}
        _G.requests = {}
        local client = vim.lsp.get_clients({ bufnr = 0, name = "asciidoc" })[1]
        local notify = client.notify
        client.notify = function(self, method, params)
            if method == "asciidoc/cursorMoved" then
                table.insert(_G.moved, params)
            end
            return notify(self, method, params)
        end
        local request = client.request
        client.request = function(self, method, params, ...)
            if method == "workspace/executeCommand" then
                table.insert(_G.requests, params)
            end
            return request(self, method, params, ...)
        end
    ]])
end

-- Wait until the stubbed vim.ui.open has been called.
local function wait_opened()
    expect.equality(child.lua_get("vim.wait(10000, function() return #_G.opened > 0 end, 20)"), true)
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
    wait_opened()
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
    wait_opened()
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

T["follows a switch to another buffer"] = function()
    helpers.edit_with_lsp(child, "tests/fixtures/basic.adoc")
    stub_client()
    child.cmd("AsciidocPreview")
    wait_opened()
    child.lua("vim.wait(300)")
    child.lua("_G.moved = {}")
    helpers.edit_with_lsp(child, "tests/fixtures/sections.adoc")
    local uri = child.lua_get("vim.uri_from_bufnr(0)")
    child.lua("vim.wait(500, function() return #_G.moved > 0 end, 20)")
    local last = child.lua_get("_G.moved[#_G.moved]")
    expect.equality(last ~= vim.NIL and last.uri, uri)
end

T["asks for the whole document by default"] = function()
    helpers.edit_with_lsp(child, "tests/fixtures/basic.adoc")
    stub_client()
    child.cmd("AsciidocPreview")
    wait_opened()
    expect.equality(child.lua_get("_G.requests[1].arguments[2].mode"), "document")
end

T["passes the part argument as mode"] = function()
    helpers.edit_with_lsp(child, "tests/fixtures/basic.adoc")
    stub_client()
    child.cmd("AsciidocPreview part")
    wait_opened()
    expect.equality(child.lua_get("_G.requests[1].arguments[2].mode"), "part")
    expect.equality(child.lua_get("_G.requests[1].arguments[1]"), child.lua_get("vim.uri_from_bufnr(0)"))
end

T["rejects an unknown mode without sending"] = function()
    helpers.edit_with_lsp(child, "tests/fixtures/basic.adoc")
    stub_client()
    child.lua([[
        _G.notified = {}
        vim.notify = function(msg, level) table.insert(_G.notified, { msg, level }) end
    ]])
    child.cmd("AsciidocPreview bogus")
    child.lua("vim.wait(300)")
    expect.equality(child.lua_get("#_G.requests"), 0)
    expect.equality(child.lua_get("_G.notified[1][2]"), child.lua_get("vim.log.levels.ERROR"))
end

T["stops sending after AsciidocPreviewStop"] = function()
    helpers.edit_with_lsp(child, "tests/fixtures/basic.adoc")
    stub_client()
    child.cmd("AsciidocPreview")
    wait_opened()
    child.lua("vim.wait(300)")
    child.lua("_G.moved = {}")
    child.api.nvim_win_set_cursor(0, { 3, 0 })
    child.cmd("doautocmd CursorMoved")
    expect.equality(child.lua_get("vim.wait(500, function() return #_G.moved > 0 end, 20)"), true)
    child.cmd("AsciidocPreviewStop")
    child.lua("vim.wait(300)")
    child.lua("_G.moved = {}")
    child.api.nvim_win_set_cursor(0, { 1, 0 })
    child.cmd("doautocmd CursorMoved")
    child.lua("vim.wait(300)")
    expect.equality(child.lua_get("#_G.moved"), 0)
end

T["follows again when the preview is reopened after a stop"] = function()
    helpers.edit_with_lsp(child, "tests/fixtures/basic.adoc")
    stub_client()
    child.cmd("AsciidocPreview")
    wait_opened()
    -- Start the throttle timer, so the stop closes one and the reopen needs a new one.
    child.api.nvim_win_set_cursor(0, { 2, 0 })
    child.cmd("doautocmd CursorMoved")
    child.cmd("AsciidocPreviewStop")
    expect.equality(child.lua_get("vim.fn.exists('#AsciidocPreview')"), 0)
    child.lua("_G.opened = {}")
    child.cmd("AsciidocPreview")
    wait_opened()
    child.lua("vim.wait(300)")
    child.lua("_G.moved = {}")
    child.api.nvim_win_set_cursor(0, { 3, 0 })
    child.cmd("doautocmd CursorMoved")
    expect.equality(child.lua_get("vim.wait(500, function() return #_G.moved > 0 end, 20)"), true)
end

T["a stop after a client restart removes the autocmds"] = function()
    helpers.edit_with_lsp(child, "tests/fixtures/basic.adoc")
    stub_client()
    child.cmd("AsciidocPreview")
    wait_opened()
    -- The first client goes away while its preview is open.
    child.lua([[
        local old = vim.lsp.get_clients({ bufnr = 0, name = "asciidoc" })[1]
        old:stop(true)
        vim.wait(5000, function() return old:is_stopped() end, 20)
    ]])
    child.cmd("bwipeout!")
    helpers.edit_with_lsp(child, "tests/fixtures/basic.adoc")
    stub_client()
    child.cmd("AsciidocPreview")
    wait_opened()
    child.cmd("AsciidocPreviewStop")
    expect.equality(child.lua_get("vim.fn.exists('#AsciidocPreview')"), 0)
end

T["does not follow when the browser fails to open"] = function()
    helpers.edit_with_lsp(child, "tests/fixtures/basic.adoc")
    stub_client()
    child.lua("_G.open_fails = true")
    child.cmd("AsciidocPreview")
    wait_opened()
    child.lua("vim.wait(300)")
    child.api.nvim_win_set_cursor(0, { 3, 0 })
    child.cmd("doautocmd CursorMoved")
    child.lua("vim.wait(300)")
    expect.equality(child.lua_get("#_G.moved"), 0)
end

T["AsciidocPreviewStop without a preview only informs"] = function()
    helpers.edit_with_lsp(child, "tests/fixtures/basic.adoc")
    child.lua([[
        _G.notified = {}
        vim.notify = function(msg, level) table.insert(_G.notified, { msg, level }) end
    ]])
    child.cmd("AsciidocPreviewStop")
    expect.equality(child.lua_get("#_G.notified"), 1)
    expect.equality(child.lua_get("_G.notified[1][2]"), child.lua_get("vim.log.levels.INFO"))
end

return T
