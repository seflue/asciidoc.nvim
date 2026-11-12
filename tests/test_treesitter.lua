local helpers = require("helpers")
local expect = MiniTest.expect

local child = helpers.new_child()

local T = MiniTest.new_set({
    hooks = {
        pre_case = child.setup,
        post_once = child.stop,
    },
})

local root = vim.g.asciidoc_nvim_root
local LANGS = { "asciidoc", "asciidoc_inline" }

--- Stub nvim-treesitter in the child, set `config` as `vim.g.asciidoc`,
--- source the plugin again and fire `User TSUpdate` as nvim-treesitter does
--- when it reloads its parser table. Returns that table.
local function register(config)
    child.lua(
        [[
        vim.g.asciidoc = ...
        package.loaded["asciidoc.config"] = nil
        _G.parsers = {}
        package.preload["nvim-treesitter"] = function() return {} end
        package.preload["nvim-treesitter.parsers"] = function() return _G.parsers end
        vim.cmd.source(vim.g.asciidoc_nvim_root .. "/plugin/asciidoc.lua")
        vim.api.nvim_exec_autocmds("User", { pattern = "TSUpdate" })
    ]],
        { config or vim.empty_dict() }
    )
    return child.lua_get("_G.parsers")
end

local function grammar()
    return child.lua_get([[(function()
        local g = require("asciidoc.grammar")
        return { url = g.url, revision = g.revision }
    end)()]])
end

T["pins both parsers to the grammar the queries are written for"] = function()
    local parsers = register()
    local pin = grammar()
    -- nvim-treesitter needs the full SHA: a GitHub tarball of a short SHA
    -- unpacks under the full one, and the install fails to find it.
    expect.equality(pin.revision:match("^%x+$") ~= nil and #pin.revision == 40, true)
    for _, lang in ipairs(LANGS) do
        expect.equality(parsers[lang].install_info.url, pin.url)
        expect.equality(parsers[lang].install_info.revision, pin.revision)
    end
end

-- nvim-treesitter downloads `revision` in preference to `branch`, so the pin
-- must give way to a url or branch override, and the pinned commit may
-- not exist in a fork.
T["overrides"] = MiniTest.new_set()

T["overrides"]["revision replaces the pin"] = function()
    local parsers = register({ treesitter = { asciidoc = { revision = "abc123" } } })
    expect.equality(parsers.asciidoc.install_info.revision, "abc123")
    expect.equality(parsers.asciidoc.install_info.url, grammar().url)
    expect.equality(parsers.asciidoc_inline.install_info.revision, grammar().revision)
end

T["overrides"]["branch drops the pin"] = function()
    local parsers = register({ treesitter = { asciidoc_inline = { branch = "my-fix" } } })
    expect.equality(parsers.asciidoc_inline.install_info.branch, "my-fix")
    expect.equality(parsers.asciidoc_inline.install_info.revision, nil)
    expect.equality(parsers.asciidoc.install_info.revision, grammar().revision)
end

local FORK = "https://github.com/you/tree-sitter-asciidoc"

T["overrides"]["url drops the pin"] = function()
    local parsers = register({ treesitter = { asciidoc = { url = FORK } } })
    expect.equality(parsers.asciidoc.install_info.url, FORK)
    expect.equality(parsers.asciidoc.install_info.revision, nil)
end

-- nvim-treesitter downloads `<url>/archive/<rev>.tar.gz`, so a local
-- checkout only builds through `install_info.path`, from the checkout as it
-- is: a revision there would only be recorded, not checked out.
T["overrides"]["path builds from a local checkout without the pin"] = function()
    local parsers = register({ treesitter = { asciidoc = { path = "/path/to/checkout" } } })
    expect.equality(parsers.asciidoc.install_info.path, "/path/to/checkout")
    expect.equality(parsers.asciidoc.install_info.location, "tree-sitter-asciidoc")
    expect.equality(parsers.asciidoc.install_info.revision, nil)
    expect.equality(parsers.asciidoc_inline.install_info.path, nil)
    expect.equality(parsers.asciidoc_inline.install_info.revision, grammar().revision)
end

T["overrides"]["url and revision keep both"] = function()
    local parsers = register({ treesitter = { asciidoc = { url = FORK, revision = "abc123" } } })
    expect.equality(parsers.asciidoc.install_info.url, FORK)
    expect.equality(parsers.asciidoc.install_info.revision, "abc123")
end

--- Stub nvim-treesitter's main API in the child: `installed` parsers, each
--- built from the revision in `revisions` (written to its parser-info
--- directory). install/update record their calls and fire `User TSUpdate`
--- as the real ones do. Then load the plugin with `config` and let its
--- scheduled work run. Returns the recorded calls. With `branch` "master"
--- the stub has the frozen master branch's module shape instead, which
--- lacks the main API; notifications land in `_G.notified`.
local function auto_install(config, installed, revisions, branch)
    child.lua(
        [[
        local config, installed, revisions, dir, branch = ...
        vim.g.asciidoc = config
        package.loaded["asciidoc.config"] = nil
        _G.calls = {}
        _G.notified = {}
        vim.notify = function(msg, level)
            table.insert(_G.notified, { msg, level })
        end
        local parsers = {}
        local function record(name)
            return function(langs)
                table.insert(_G.calls, { name, langs })
                vim.api.nvim_exec_autocmds("User", { pattern = "TSUpdate" })
            end
        end
        package.preload["nvim-treesitter"] = function()
            if branch == "master" then
                return { setup = function() end }
            end
            return {
                get_installed = function() return installed end,
                install = record("install"),
                update = record("update"),
            }
        end
        package.preload["nvim-treesitter.parsers"] = function() return parsers end
        package.preload["nvim-treesitter.config"] = function()
            return {
                get_install_dir = function(name)
                    local path = dir .. "/" .. name
                    vim.fn.mkdir(path, "p")
                    return path
                end,
            }
        end
        vim.fn.mkdir(dir .. "/parser-info", "p")
        for lang, rev in pairs(revisions) do
            vim.fn.writefile({ rev }, dir .. "/parser-info/" .. lang .. ".revision")
        end
        vim.cmd.source(vim.g.asciidoc_nvim_root .. "/plugin/asciidoc.lua")
        vim.wait(100)
    ]],
        { config, installed, revisions, vim.fn.tempname(), branch or "main" }
    )
    expect.equality(child.lua_get("vim.v.errmsg"), "")
    return child.lua_get("_G.calls")
end

local AUTO = { treesitter = { auto_install = true } }

T["auto_install"] = MiniTest.new_set()

T["auto_install"]["installs missing parsers once"] = function()
    expect.equality(auto_install(AUTO, {}, vim.empty_dict()), { { "install", LANGS } })
end

T["auto_install"]["leaves parsers built from the pin alone"] = function()
    local pin = grammar().revision
    local calls = auto_install(AUTO, LANGS, { asciidoc = pin, asciidoc_inline = pin })
    expect.equality(calls, {})
end

T["auto_install"]["rebuilds parsers built from another revision"] = function()
    local calls = auto_install(AUTO, LANGS, { asciidoc = "develop", asciidoc_inline = grammar().revision })
    expect.equality(calls, { { "update", { "asciidoc" } } })
end

T["auto_install"]["does nothing unless enabled"] = function()
    local calls = auto_install(vim.empty_dict(), {}, vim.empty_dict())
    expect.equality(calls, {})
    expect.equality(child.lua_get("_G.notified"), {})
end

-- The main API (get_installed/install/update) is missing on master; the
-- plugin warns once at load instead of raising an error at every startup.
T["auto_install"]["warns instead of failing on nvim-treesitter master"] = function()
    local calls = auto_install(AUTO, {}, vim.empty_dict(), "master")
    expect.equality(calls, {})
    local notified = child.lua_get("_G.notified")
    expect.equality(#notified, 1)
    expect.equality(notified[1][2], vim.log.levels.WARN)
    expect.equality(notified[1][1]:find(":TSInstall asciidoc asciidoc_inline", 1, true) ~= nil, true)
end

-- The test parsers in deps/site are built from the justfile's grammar_rev,
-- so the query tests run against the pinned grammar only if both agree.
T["builds the test parsers from the pinned revision"] = function()
    local rev = vim.fn.system({ "just", "-f", root .. "/justfile", "--evaluate", "grammar_rev" })
    expect.equality(vim.v.shell_error, 0)
    expect.equality(rev, grammar().revision)
end

--- Put a `highlights.scm` naming a node type no parser has ahead of the
--- bundled one, as a parser older than the queries sees them, add a
--- FileType autocmd that compiles the query without pcall as LazyVim's does,
--- load the plugin and open `basic.adoc`. A replaced query is one `get`
--- no longer raises on: it finds none, so highlighting stays off until the
--- parser is updated. With `stale` false nothing is put ahead. Returns what
--- the buffer ended up with.
local function open_with_parser(stale)
    return child.lua(
        [[
        local stale, root = ...
        if stale then
            local dir = vim.fn.tempname()
            vim.fn.mkdir(dir .. "/queries/asciidoc", "p")
            vim.fn.writefile({ "(no_such_node) @markup.heading" }, dir .. "/queries/asciidoc/highlights.scm")
            vim.opt.runtimepath:prepend(dir)
        end
        _G.notified = {}
        vim.notify = function(msg, level)
            table.insert(_G.notified, { msg, level })
        end
        vim.api.nvim_create_autocmd("FileType", {
            pattern = "asciidoc",
            callback = function(ev)
                vim.treesitter.query.get("asciidoc", "highlights")
                vim.b[ev.buf].set_up = true
            end,
        })
        vim.cmd.source(root .. "/plugin/asciidoc.lua")
        vim.v.errmsg = ""
        vim.cmd.edit(root .. "/tests/fixtures/basic.adoc")
        return {
            errmsg = vim.v.errmsg,
            filetype = vim.bo.filetype,
            set_up = vim.b.set_up,
            notified = _G.notified,
            folds = pcall(vim.treesitter.query.get, "asciidoc", "folds"),
        }
    ]],
        { stale, root }
    )
end

T["outdated parser"] = MiniTest.new_set()

T["outdated parser"]["leaves the buffer set up and asks for an update"] = function()
    local got = open_with_parser(true)
    expect.equality(got.errmsg, "")
    expect.equality(got.filetype, "asciidoc")
    expect.equality(got.set_up, true)
    expect.equality(#got.notified, 1)
    expect.equality(got.notified[1][2], vim.log.levels.WARN)
    expect.equality(got.notified[1][1]:find("asciidoc/highlights", 1, true) ~= nil, true)
    expect.equality(got.notified[1][1]:find(":TSUpdate asciidoc asciidoc_inline", 1, true) ~= nil, true)
    expect.equality(got.folds, true)
end

-- vim.treesitter.query.get caches a miss too and forgets it only on
-- OptionSet runtimepath, which lazy.nvim does not fire when it adds a
-- plugin: a picker preview of an AsciiDoc file before the plugin loads left
-- every later buffer without highlighting.
T["finds its queries after a lookup from before it was on the runtimepath"] = function()
    local got = child.lua(
        [[
        local root = ...
        vim.cmd("noautocmd set runtimepath-=" .. root)
        vim.treesitter.query.get:clear()
        local before = #vim.treesitter.query.get_files("asciidoc", "highlights")
        local missed = vim.treesitter.query.get("asciidoc", "highlights") == nil
        vim.cmd("noautocmd set runtimepath^=" .. root)
        vim.cmd.source(root .. "/plugin/asciidoc.lua")
        vim.cmd.edit(root .. "/tests/fixtures/basic.adoc")
        local query = vim.treesitter.query.get("asciidoc", "highlights")
        return { before = before, missed = missed, found = query ~= nil and #query.captures > 0 }
    ]],
        { root }
    )
    expect.equality(got, { before = 0, missed = true, found = true })
end

T["outdated parser"]["keeps the queries of a parser they compile against"] = function()
    local got = open_with_parser(false)
    expect.equality(got.errmsg, "")
    expect.equality(got.notified, {})
    expect.equality(child.lua_get("#vim.treesitter.query.get('asciidoc', 'highlights').captures > 0"), true)
end

return T
