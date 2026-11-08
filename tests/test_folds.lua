local helpers = require("helpers")
local expect = MiniTest.expect

local child = helpers.new_child()

local T = MiniTest.new_set({
    hooks = {
        pre_case = child.setup,
        post_once = child.stop,
    },
})

T["folds each section including nested ones, and delimited blocks"] = function()
    child.cmd("edit " .. vim.g.asciidoc_nvim_root .. "/tests/fixtures/sections.adoc")
    expect.equality(helpers.capture_ranges(child, "folds", "fold"), {
        { 2, 0, 14, 0 },
        { 7, 0, 9, 4 },
        { 11, 0, 14, 0 },
        { 15, 0, 18, 0 },
    })
end

return T
