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

-- Open the preview on a 200-line buffer, cursor and view on line 1.
local function open_long_buffer()
    helpers.edit_with_lsp(child, "tests/fixtures/basic.adoc")
    stub_client()
    child.lua([[
        local lines = {}
        for i = 1, 200 do lines[i] = "Line " .. i end
        vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        vim.fn.winrestview({ topline = 1 })
    ]])
    child.cmd("AsciidocPreview")
    wait_opened()
    child.lua("vim.wait(300)")
end

-- Deliver asciidoc/revealLine from the buffer's client, as the server sends it.
local function reveal(uri, line, cursor)
    child.lua(
        [[
        local uri, line, cursor = ...
        local client = vim.lsp.get_clients({ bufnr = 0, name = "asciidoc" })[1]
        local handler = client.handlers["asciidoc/revealLine"] or vim.lsp.handlers["asciidoc/revealLine"]
        handler(nil, { uri = uri, line = line, cursor = cursor }, { client_id = client.id, method = "asciidoc/revealLine" })
    ]],
        { uri, line, cursor == true }
    )
end

T["revealLine puts the line at the top of the window"] = function()
    open_long_buffer()
    -- LSP line 99 is buffer line 100.
    reveal(child.lua_get("vim.uri_from_bufnr(0)"), 99)
    expect.equality(child.lua_get("vim.fn.line('w0')"), 100)
end

T["revealLine for another file changes nothing"] = function()
    open_long_buffer()
    reveal(vim.uri_from_fname("/elsewhere/other.adoc"), 99)
    expect.equality(child.lua_get("vim.fn.line('w0')"), 1)
    expect.equality(child.lua_get("vim.api.nvim_win_get_cursor(0)[1]"), 1)
end

T["revealLine does not scroll when the line is already at the top"] = function()
    open_long_buffer()
    child.lua("vim.api.nvim_win_set_cursor(0, { 60, 0 }); vim.fn.winrestview({ topline = 50 })")
    local uri = child.lua_get("vim.uri_from_bufnr(0)")
    -- Buffer lines 50 and 51: the page's rounding, not a move.
    reveal(uri, 49)
    expect.equality(child.lua_get("vim.fn.line('w0')"), 50)
    reveal(uri, 50)
    expect.equality(child.lua_get("vim.fn.line('w0')"), 50)
end

T["revealLine is ignored while no preview follows the buffer"] = function()
    helpers.edit_with_lsp(child, "tests/fixtures/basic.adoc")
    child.lua([[
        local lines = {}
        for i = 1, 200 do lines[i] = "Line " .. i end
        vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
        require("asciidoc.preview")
    ]])
    child.lua(
        "require('asciidoc.preview').on_reveal_line(nil, { uri = ..., line = 99 })",
        { child.lua_get("vim.uri_from_bufnr(0)") }
    )
    expect.equality(child.lua_get("vim.fn.line('w0')"), 1)
end

T["revealLine with cursor puts the cursor on a line that is already in view"] = function()
    open_long_buffer()
    -- The window shows line 1 on: the view has nothing to do.
    child.lua("vim.api.nvim_win_set_cursor(0, { 3, 2 })")
    reveal(child.lua_get("vim.uri_from_bufnr(0)"), 9, true)
    expect.equality(child.lua_get("vim.fn.line('w0')"), 1)
    expect.equality(child.lua_get("vim.api.nvim_win_get_cursor(0)"), { 10, 0 })
end

T["revealLine with cursor puts a line out of view at the top, with the cursor"] = function()
    open_long_buffer()
    child.lua("vim.api.nvim_win_set_cursor(0, { 150, 4 }); vim.fn.winrestview({ topline = 140 })")
    -- Let the setup's own cursor report go out first.
    child.cmd("doautocmd CursorMoved")
    child.lua("vim.wait(300)")
    child.lua("_G.moved = {}")
    reveal(child.lua_get("vim.uri_from_bufnr(0)"), 0, true)
    expect.equality(child.lua_get("vim.fn.line('w0')"), 1)
    expect.equality(child.lua_get("vim.api.nvim_win_get_cursor(0)"), { 1, 0 })
    child.cmd("doautocmd CursorMoved")
    child.lua("vim.wait(300)")
    expect.equality(child.lua_get("#_G.moved"), 0)
end

T["revealLine with cursor past the end of the file goes to its last line"] = function()
    open_long_buffer()
    reveal(child.lua_get("vim.uri_from_bufnr(0)"), 2147483646, true)
    local last = child.lua_get("vim.api.nvim_buf_line_count(0)")
    expect.equality(child.lua_get("vim.api.nvim_win_get_cursor(0)"), { last, 0 })
end

T["revealLine without cursor leaves a cursor in the new view where it is"] = function()
    open_long_buffer()
    child.lua("vim.api.nvim_win_set_cursor(0, { 15, 2 })")
    reveal(child.lua_get("vim.uri_from_bufnr(0)"), 9)
    expect.equality(child.lua_get("vim.fn.line('w0')"), 10)
    expect.equality(child.lua_get("vim.api.nvim_win_get_cursor(0)"), { 15, 2 })
end

T["the cursor move a revealLine forces is not sent back"] = function()
    open_long_buffer()
    child.lua("_G.moved = {}")
    reveal(child.lua_get("vim.uri_from_bufnr(0)"), 99)
    -- The cursor had to follow the view.
    expect.equality(child.lua_get("vim.api.nvim_win_get_cursor(0)[1] >= 100"), true)
    child.cmd("doautocmd CursorMoved")
    child.lua("vim.wait(300)")
    expect.equality(child.lua_get("#_G.moved"), 0)
end

T["the cursor steps of an animated revealLine are not sent back"] = function()
    -- Animated scrolling (mini.animate) walks the cursor from where it was
    -- to where revealLine put it, one CursorMoved per step, and takes
    -- longer than the echo window.
    open_long_buffer()
    child.lua("vim.api.nvim_win_set_cursor(0, { 150, 0 }); vim.fn.winrestview({ topline = 140 })")
    child.cmd("doautocmd CursorMoved")
    child.lua("vim.wait(300)")
    child.lua("_G.moved = {}")
    reveal(child.lua_get("vim.uri_from_bufnr(0)"), 99)
    local target = child.lua_get("vim.api.nvim_win_get_cursor(0)[1]")
    -- Steps past the start, as overlapping animations produce them, and
    -- long after the reveal: no key was typed, so none is the user's.
    for _, row in ipairs({ 148, 160, 132, target + 2, target - 3, target }) do
        child.lua("vim.api.nvim_win_set_cursor(0, { ... , 0 })", { row })
        child.cmd("doautocmd CursorMoved")
        child.lua("vim.wait(120)")
    end
    child.lua("vim.wait(300)")
    expect.equality(child.lua_get("#_G.moved"), 0)
end

T["revealLine puts the line at the top of the window also with wrapped lines"] = function()
    open_long_buffer()
    child.lua([[
        local lines = {}
        for i = 1, 200 do lines[i] = "Line " .. i .. " " .. string.rep("word ", 60) end
        vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
        vim.wo.wrap = true
        vim.api.nvim_win_set_cursor(0, { 150, 0 })
    ]])
    reveal(child.lua_get("vim.uri_from_bufnr(0)"), 9)
    expect.equality(child.lua_get("vim.fn.line('w0')"), 10)
end

T["a cursor move of the user right after a revealLine is sent, also on the reveal's way"] = function()
    open_long_buffer()
    child.lua("vim.api.nvim_win_set_cursor(0, { 150, 0 }); vim.fn.winrestview({ topline = 140 })")
    child.cmd("doautocmd CursorMoved")
    child.lua("vim.wait(300)")
    reveal(child.lua_get("vim.uri_from_bufnr(0)"), 99)
    child.cmd("doautocmd CursorMoved")
    child.lua("_G.moved = {}")
    -- Typed at once, to a row between where the cursor was and where it went.
    child.type_keys("130G")
    expect.equality(child.lua_get("vim.wait(500, function() return #_G.moved > 0 end, 20)"), true)
    expect.equality(child.lua_get("_G.moved[#_G.moved].line"), 129)
end

T["entering another buffer after a revealLine is reported without a typed key"] = function()
    -- A double-click in the page opens a file by window/showDocument, which
    -- types nothing; going back to the revealed buffer must be reported.
    open_long_buffer()
    local uri = child.lua_get("vim.uri_from_bufnr(0)")
    reveal(uri, 99)
    child.lua("_G.revealed = vim.api.nvim_get_current_buf()")
    child.lua("vim.cmd.enew(); vim.wait(200)")
    child.lua("_G.moved = {}")
    child.lua("vim.api.nvim_set_current_buf(_G.revealed)")
    expect.equality(child.lua_get("vim.wait(500, function() return #_G.moved > 0 end, 20)"), true)
    expect.equality(child.lua_get("_G.moved[#_G.moved].uri"), uri)
end

T["a cursor report still pending when a revealLine arrives does not send the forced cursor"] = function()
    open_long_buffer()
    child.lua("_G.moved = {}")
    -- The user's G starts the send throttle; the reveal lands before it fires.
    child.type_keys("G")
    reveal(child.lua_get("vim.uri_from_bufnr(0)"), 49, true)
    child.lua("vim.wait(300)")
    local lines = child.lua_get("vim.tbl_map(function(m) return m.line end, _G.moved)")
    expect.equality(vim.tbl_contains(lines, 49), false)
end

T["completes the modes, debug and its actions"] = function()
    helpers.edit_with_lsp(child, "tests/fixtures/basic.adoc")
    expect.equality(child.fn.getcompletion("AsciidocPreview ", "cmdline"), { "document", "part", "debug" })
    expect.equality(child.fn.getcompletion("AsciidocPreview d", "cmdline"), { "document", "debug" })
    expect.equality(child.fn.getcompletion("AsciidocPreview debug ", "cmdline"), { "on", "off", "show" })
    expect.equality(child.fn.getcompletion("AsciidocPreview debug o", "cmdline"), { "on", "off" })
    expect.equality(child.fn.getcompletion("AsciidocPreview part ", "cmdline"), {})
end

-- Capture notifications instead of showing them.
local function capture_notify()
    child.lua([[
        _G.notified = {}
        vim.notify = function(msg, level) table.insert(_G.notified, { msg, level }) end
    ]])
end

-- Wait until `count` notifications have arrived.
local function wait_notified(count)
    expect.equality(
        child.lua_get("vim.wait(10000, function() return #_G.notified >= " .. count .. " end, 20)"),
        true
    )
end

T["debug on and off switch the server's debug log"] = function()
    helpers.edit_with_lsp(child, "tests/fixtures/basic.adoc")
    stub_client()
    child.cmd("AsciidocPreview")
    wait_opened()
    capture_notify()
    child.cmd("AsciidocPreview debug on")
    wait_notified(1)
    expect.equality(child.lua_get("_G.requests[2]"), { command = "asciidoc.preview.debug", arguments = { "on" } })
    expect.equality(child.lua_get("_G.notified[1]"), { "AsciidocPreview: debug on", child.lua_get("vim.log.levels.INFO") })
    child.cmd("AsciidocPreview debug off")
    wait_notified(2)
    expect.equality(child.lua_get("_G.requests[3].arguments"), { "off" })
    expect.equality(child.lua_get("_G.notified[2][1]"), "AsciidocPreview: debug off")
end

T["debug without an open preview reports the server's error"] = function()
    helpers.edit_with_lsp(child, "tests/fixtures/basic.adoc")
    stub_client()
    capture_notify()
    child.cmd("AsciidocPreview debug on")
    wait_notified(1)
    expect.equality(child.lua_get("_G.notified[1][2]"), child.lua_get("vim.log.levels.ERROR"))
    expect.equality(child.lua_get("_G.notified[1][1]:find('no preview is open', 1, true) ~= nil"), true)
end

T["debug rejects an unknown action without sending"] = function()
    helpers.edit_with_lsp(child, "tests/fixtures/basic.adoc")
    stub_client()
    capture_notify()
    child.cmd("AsciidocPreview debug loud")
    child.cmd("AsciidocPreview debug")
    expect.equality(child.lua_get("#_G.requests"), 0)
    expect.equality(child.lua_get("#_G.notified"), 2)
    expect.equality(child.lua_get("_G.notified[2][2]"), child.lua_get("vim.log.levels.ERROR"))
end

T["debug show opens the log as a table"] = function()
    helpers.edit_with_lsp(child, "tests/fixtures/basic.adoc")
    stub_client()
    child.cmd("AsciidocPreview")
    wait_opened()
    capture_notify()
    child.cmd("AsciidocPreview debug on")
    wait_notified(1)
    child.lua("vim.api.nvim_win_set_cursor(0, { 3, 0 })")
    child.lua("vim.api.nvim_exec_autocmds('CursorMoved', {})")
    expect.equality(
        child.lua_get("vim.wait(10000, function() return #_G.moved > 0 and _G.moved[#_G.moved].line == 2 end, 20)"),
        true
    )
    child.cmd("AsciidocPreview debug show")
    expect.equality(child.lua_get("vim.wait(10000, function() return vim.bo.filetype == 'markdown' end, 20)"), true)
    local lines = child.lua_get("vim.api.nvim_buf_get_lines(0, 0, -1, false)")
    expect.equality(lines[1], "# Preview scroll debug (on)")
    expect.equality(lines[3]:match("^| seq | sent ") ~= nil, true)
    expect.equality(lines[5]:match("^| 1 | basic%.adoc:3 |") ~= nil, true)
end

-- The table rows of a debug log: one per page report, the sent cursor on
-- the first row of each pair only.
T["debug_table renders sent cursor and page reports side by side"] = function()
    local lines = child.lua_get([[require("asciidoc.preview").debug_table({
        enabled = false,
        pairs = {
            { seq = 1, sent = { file = "/b/doc.adoc", line = 1 }, page = {
                { seq = 1, kind = "reveal", file = "/b/doc.adoc", line = 1, src = vim.NIL, skipped = vim.NIL,
                  prev = { line = 1, y = 0, what = "synthetic" },
                  next = { line = 12, y = 4800, what = "paragraph data-line-12" },
                  target = 4800, action = "align", scrollBefore = 0, scrollAfter = 4800, viewport = 900 },
                { seq = 1, kind = "html", file = "/b/doc.adoc", following = true, keepLine = vim.NIL,
                  scrollBefore = 4800, scrollAfter = 4800 },
                { seq = 1, kind = "scroll", file = "/b/ch.adoc", line = 7, cursor = false, scrollY = 5000 },
            } },
            { seq = 2, sent = { file = "/b/doc.adoc", line = 5 }, page = {} },
            { seq = 3, sent = vim.NIL, page = {
                { seq = 3, kind = "reveal", file = "/b/x.adoc", line = 2, src = "not-shown", skipped = "not-shown",
                  prev = vim.NIL, next = vim.NIL, target = vim.NIL, action = vim.NIL,
                  scrollBefore = 10, scrollAfter = 10, viewport = 900 },
                { seq = 3, kind = "html", file = "/b/doc.adoc", following = vim.NIL, keepLine = vim.NIL,
                  scrollBefore = vim.NIL, scrollAfter = 10 },
                { seq = 3, kind = "scroll", file = "/b/a|b.adoc", line = 4, cursor = vim.NIL, scrollY = 0 },
            } },
        },
    })]])
    expect.equality(lines, {
        "# Preview scroll debug (off)",
        "",
        "| seq | sent | kind | page | src | prev | next | target | action | scrollY | viewport | note |",
        "|---|---|---|---|---|---|---|---|---|---|---|---|",
        "| 1 | doc.adoc:1 | reveal | doc.adoc:1 | main | 1@0 synthetic | 12@4800 paragraph data-line-12 | 4800 | align | 0→4800 | 900 | |",
        "| | | html | doc.adoc | | | | | | 4800→4800 | | following |",
        "| | | scroll | ch.adoc:7 | | | | | | 5000 | | to editor |",
        "| 2 | doc.adoc:5 | – | | | | | | | | | no report |",
        "| 3 | (unpaired) | reveal | x.adoc:2 | not-shown | | | | | 10 | 900 | skipped: not-shown |",
        "| | | html | doc.adoc | | | | | | →10 | | keep line |",
        "| | | scroll | a\\|b.adoc:4 | | | | | | 0 | | to editor |",
    })
end

T["debug show without a log from the server reports an error"] = function()
    helpers.edit_with_lsp(child, "tests/fixtures/basic.adoc")
    capture_notify()
    child.lua([[
        local client = vim.lsp.get_clients({ bufnr = 0, name = "asciidoc" })[1]
        client.request = function(_, _, _, handler) handler(nil, vim.NIL) return true, 1 end
    ]])
    child.cmd("AsciidocPreview debug show")
    expect.equality(child.lua_get("_G.notified[1][2]"), child.lua_get("vim.log.levels.ERROR"))
    expect.equality(child.lua_get("#vim.api.nvim_list_wins()"), 1)
end

return T
