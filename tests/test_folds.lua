local helpers = require("helpers")
local expect = MiniTest.expect

local child = helpers.new_child()

local T = MiniTest.new_set({
    hooks = {
        pre_case = child.setup,
        post_once = child.stop,
    },
})

T["folds each section including nested ones and its anchor, and delimited blocks"] = function()
    child.cmd("edit " .. vim.g.asciidoc_nvim_root .. "/tests/fixtures/sections.adoc")
    expect.equality(helpers.capture_ranges(child, "folds", "fold"), {
        { 2, 0, 14, 0 },
        { 7, 0, 9, 4 },
        { 11, 0, 14, 0 },
        { 15, 0, 19, 0 },
    })
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
