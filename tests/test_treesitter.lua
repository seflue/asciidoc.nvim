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

-- The test parsers in deps/site are built from the justfile's grammar_rev,
-- so the query tests run against the pinned grammar only if both agree.
T["builds the test parsers from the pinned revision"] = function()
    local rev = vim.fn.system({ "just", "-f", root .. "/justfile", "--evaluate", "grammar_rev" })
    expect.equality(vim.v.shell_error, 0)
    expect.equality(rev, grammar().revision)
end

return T
