local helpers = require("helpers")
local expect = MiniTest.expect

local child = helpers.new_child()

local T = MiniTest.new_set({
    hooks = {
        pre_case = child.setup,
        post_once = child.stop,
    },
})

T["attaches asciidoc-lsp to an asciidoc buffer"] = function()
    helpers.edit_with_lsp(child, "tests/fixtures/basic.adoc")
    expect.equality(child.bo.filetype, "asciidoc")
end

return T
