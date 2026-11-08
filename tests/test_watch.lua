-- File watching: the client lets asciidoc-lsp register watchers, and the
-- server picks up config changes on disk without an edit to the buffer.
-- Files sit in the workspace root: on Linux without inotifywait, Neovim
-- delivers no events for subdirectories.
local helpers = require("helpers")
local expect = MiniTest.expect

local child = helpers.new_child()

local T = MiniTest.new_set({
    hooks = {
        pre_case = function()
            child.setup()
            -- Record the server's registrations, before any client starts.
            child.lua([[
                _G.registrations = {}
                local orig = vim.lsp.handlers["client/registerCapability"]
                vim.lsp.handlers["client/registerCapability"] = function(err, params, ctx)
                    for _, reg in ipairs(params.registrations) do
                        table.insert(_G.registrations, reg.method)
                    end
                    return orig(err, params, ctx)
                end
            ]])
        end,
        post_once = child.stop,
    },
})

local function write(path, lines)
    vim.fn.writefile(lines, path)
end

--- Workspace root (`.git` as root marker) with `a.adoc` using `{watchprobe}`
--- and, if `value` is given, a `.asciidoctorconfig` defining it. Returns the
--- canonical root.
local function project(value)
    local tmp = vim.fn.tempname()
    vim.fn.mkdir(tmp .. "/.git", "p")
    local root = assert(vim.uv.fs_realpath(tmp))
    write(root .. "/a.adoc", { "= A", "", "Probe: {watchprobe}" })
    if value then
        write(root .. "/.asciidoctorconfig", { ":watchprobe: " .. value })
    end
    return root
end

local function watcher_registrations()
    return child.lua_get([[(function()
        vim.wait(2000, function() return #_G.registrations > 0 end, 20)
        return vim.tbl_filter(function(m)
            return m == "workspace/didChangeWatchedFiles"
        end, _G.registrations)
    end)()]])
end

--- Whether hover on `{watchprobe}` contains `needle`, polling up to
--- `timeout` ms for the state `want`. Returns the state the wait ended in.
local function hover_has(needle, want, timeout)
    child.fn.search("{watchprobe}", "w")
    child.cmd("normal! l")
    return child.lua_get(
        [[(function(needle, want, timeout)
        local has = not want
        vim.wait(timeout, function()
            local params = vim.lsp.util.make_position_params(0, "utf-16")
            local res = vim.lsp.buf_request_sync(0, "textDocument/hover", params, 1000)
            local text = ""
            for _, r in pairs(res or {}) do
                local c = r.result and r.result.contents
                if c then
                    text = type(c) == "table" and (c.value or "") or c
                end
            end
            has = text:find(needle, 1, true) ~= nil
            return has == want
        end, 100)
        return has
    end)(...)]],
        { needle, want, timeout }
    )
end

T["advertises dynamic registration of watched files"] = function()
    helpers.edit_with_lsp(child, project("hello") .. "/a.adoc")
    local caps = child.lua_get([[vim.lsp.get_clients({ bufnr = 0, name = "asciidoc" })[1].capabilities]])
    expect.equality(caps.workspace.didChangeWatchedFiles.dynamicRegistration, true)
    -- The partial table merges into Neovim's defaults instead of replacing them.
    expect.equality(caps.textDocument.hover ~= nil, true)
end

T["server registers its file watchers"] = function()
    helpers.edit_with_lsp(child, project("hello") .. "/a.adoc")
    expect.equality(watcher_registrations(), { "workspace/didChangeWatchedFiles" })
end

T["a user config can turn dynamic registration off"] = function()
    child.lua([[vim.lsp.config("asciidoc", {
        capabilities = { workspace = { didChangeWatchedFiles = { dynamicRegistration = false } } },
    })]])
    helpers.edit_with_lsp(child, project("hello") .. "/a.adoc")
    expect.equality(watcher_registrations(), {})
end

-- Manual test plan T9.2 without watcher timing: the event is sent by hand.
T["hover shows a changed config value after a watch event"] = function()
    child.lua([[vim.lsp.config("asciidoc", {
        capabilities = { workspace = { didChangeWatchedFiles = { dynamicRegistration = false } } },
    })]])
    local root = project("hello")
    helpers.edit_with_lsp(child, root .. "/a.adoc")
    expect.equality(hover_has(":watchprobe: hello", true, 2000), true)

    write(root .. "/.asciidoctorconfig", { ":watchprobe: bonjour" })
    child.lua(
        [[vim.lsp.get_clients({ bufnr = 0, name = "asciidoc" })[1]:notify(
            "workspace/didChangeWatchedFiles", { changes = { { uri = ..., type = 2 } } })]],
        { vim.uri_from_fname(root .. "/.asciidoctorconfig") }
    )

    expect.equality(hover_has(":watchprobe: bonjour", true, 2000), true)
    expect.equality(child.bo.modified, false)
end

-- Manual test plan T9.1-T9.3 with Neovim's own watcher.
T["hover follows config created, changed and deleted on disk"] = function()
    local root = project(nil)
    helpers.edit_with_lsp(child, root .. "/a.adoc")
    expect.equality(#watcher_registrations(), 1)
    expect.equality(hover_has(":watchprobe:", false, 500), false)

    local config = root .. "/.asciidoctorconfig"
    write(config, { ":watchprobe: hello" })
    expect.equality(hover_has(":watchprobe: hello", true, 3000), true)

    write(config, { ":watchprobe: bonjour" })
    expect.equality(hover_has(":watchprobe: bonjour", true, 3000), true)

    vim.fn.delete(config)
    expect.equality(hover_has(":watchprobe:", false, 3000), false)
    expect.equality(child.bo.modified, false)
end

return T
