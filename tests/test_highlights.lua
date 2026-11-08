local helpers = require("helpers")
local expect = MiniTest.expect

local child = helpers.new_child()

local T = MiniTest.new_set({
    hooks = {
        pre_case = child.setup,
        post_once = child.stop,
    },
})

T["highlights a block anchor's brackets, id and reftext"] = function()
    child.cmd("edit " .. vim.g.asciidoc_nvim_root .. "/tests/fixtures/sections.adoc")
    local ranges = function(capture)
        return vim.tbl_filter(function(range)
            return range[1] == 15
        end, helpers.capture_ranges(child, "highlights", capture))
    end
    expect.equality(ranges("punctuation.delimiter"), { { 15, 0, 15, 2 }, { 15, 20, 15, 22 } })
    expect.equality(ranges("label"), { { 15, 2, 15, 8 } })
    expect.equality(ranges("markup.link.label"), { { 15, 9, 15, 20 } })
end

return T
