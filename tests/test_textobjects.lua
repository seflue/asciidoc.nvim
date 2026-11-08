local helpers = require("helpers")
local expect = MiniTest.expect

local child = helpers.new_child()

local T = MiniTest.new_set({
    hooks = {
        pre_case = child.setup,
        post_once = child.stop,
    },
})

T["@section.outer spans each section including nested ones"] = function()
    child.cmd("edit " .. vim.g.asciidoc_nvim_root .. "/tests/fixtures/sections.adoc")
    expect.equality(helpers.capture_ranges(child, "textobjects", "section.outer"), {
        { 2, 0, 14, 0 },
        { 11, 0, 14, 0 },
        { 15, 0, 18, 0 },
    })
end

T["@section.inner spans each section's content after the title"] = function()
    child.cmd("edit " .. vim.g.asciidoc_nvim_root .. "/tests/fixtures/sections.adoc")
    expect.equality(helpers.capture_ranges(child, "textobjects", "section.inner"), {
        { 5, 0, 14, 0 },
        { 13, 0, 14, 0 },
        { 17, 0, 18, 0 },
    })
end

return T
