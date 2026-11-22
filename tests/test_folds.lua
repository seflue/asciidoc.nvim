local helpers = require("helpers")
local expect = MiniTest.expect

local child = helpers.new_child()

local T = MiniTest.new_set({
    hooks = {
        pre_case = child.setup,
        post_once = child.stop,
    },
})

local sections = vim.g.asciidoc_nvim_root .. "/tests/fixtures/sections.adoc"

T["a section folds without any fold configuration"] = function()
    child.cmd("edit " .. sections)
    -- "First paragraph." sits one level deep, in `== First Section`
    expect.equality(child.fn.foldlevel(6), 1)
end

T["the user's foldlevel decides which folds start closed"] = function()
    child.cmd("edit " .. sections)
    -- Neovim's default foldlevel 0: every section starts closed
    expect.equality(child.wo.foldlevel, 0)
    expect.equality(child.fn.foldclosed(6), 4)

    child.restart({
        "--cmd",
        "set foldlevelstart=99",
        "-u",
        vim.g.asciidoc_nvim_root .. "/tests/minimal_init.lua",
    })
    child.cmd("edit " .. sections)
    expect.equality(child.wo.foldlevel, 99)
    expect.equality(child.fn.foldclosed(6), -1)
end

T["folds are left alone when turned off"] = function()
    child.restart({
        "--cmd",
        "lua vim.g.asciidoc = { folds = { enable = false } }",
        "-u",
        vim.g.asciidoc_nvim_root .. "/tests/minimal_init.lua",
    })
    child.cmd("edit " .. sections)
    -- the ftplugin did run
    expect.equality(child.bo.commentstring, "// %s")
    expect.equality(child.wo.foldmethod, "manual")
    expect.equality(child.fn.foldlevel(6), 0)
end

T["sidebars, passthroughs, quotes, tables, lists and comments fold"] = function()
    child.cmd("edit " .. vim.g.asciidoc_nvim_root .. "/tests/fixtures/folds.adoc")
    local levels = {}
    -- the paragraph, then one line inside each block, in fixture order
    for _, line in ipairs({ 1, 4, 8, 12, 15, 20, 25, 28 }) do
        levels[#levels + 1] = child.fn.foldlevel(line)
    end
    expect.equality(levels, { 0, 1, 1, 1, 1, 1, 1, 1 })
end

T["example, literal, open and quote blocks, pipe tables and lists fold"] = function()
    child.cmd("edit " .. vim.g.asciidoc_nvim_root .. "/tests/fixtures/folds.adoc")
    local levels = {}
    -- `[NOTE]` with `====`, then `....`, `--`, `____`, `|===`, `* one`
    for _, line in ipairs({ 33, 37, 41, 45, 49, 52 }) do
        levels[#levels + 1] = child.fn.foldlevel(line)
    end
    expect.equality(levels, { 1, 1, 1, 1, 1, 1 })
end

T["a block title stays outside the block fold"] = function()
    child.cmd("edit " .. vim.g.asciidoc_nvim_root .. "/tests/fixtures/folds.adoc")
    expect.equality(child.fn.foldlevel(55), 0)
    expect.equality(child.fn.foldclosed(58), 57)
end

T["a block inside a sidebar folds one level deeper"] = function()
    child.cmd("edit " .. vim.g.asciidoc_nvim_root .. "/tests/fixtures/folds.adoc")
    expect.equality({ child.fn.foldlevel(62), child.fn.foldlevel(65) }, { 1, 2 })
end

T["folds each section from its title, nested ones too, and delimited blocks"] = function()
    child.cmd("edit " .. vim.g.asciidoc_nvim_root .. "/tests/fixtures/sections.adoc")
    -- `[appendix]` and `[[second,...]]` stay outside, so a closed fold shows the title
    expect.equality(helpers.capture_ranges(child, "folds", "fold"), {
        { 3, 0, 14, 0 },
        { 7, 0, 9, 4 },
        { 11, 0, 14, 0 },
        { 16, 0, 19, 0 },
    })
end

T["a closed section fold shows its title"] = function()
    child.cmd("edit " .. vim.g.asciidoc_nvim_root .. "/tests/fixtures/sections.adoc")
    expect.equality(child.fn.foldclosed(6), 4)
    expect.equality(child.fn.foldclosed(19), 17)
end

T["an attribute entry in a section body keeps the section and its subsections"] = function()
    child.cmd("edit " .. vim.g.asciidoc_nvim_root .. "/tests/fixtures/attribute_entries.adoc")
    expect.equality(helpers.capture_ranges(child, "folds", "fold"), {
        { 0, 0, 12, 0 },
        { 5, 0, 12, 0 },
        { 9, 0, 12, 0 },
    })
end

T["a `:to` line in the header keeps the first section"] = function()
    child.cmd("edit " .. vim.g.asciidoc_nvim_root .. "/tests/fixtures/attribute_header.adoc")
    expect.equality(helpers.capture_ranges(child, "folds", "fold"), {
        { 4, 0, 11, 0 },
        { 8, 0, 11, 0 },
    })
end

return T
