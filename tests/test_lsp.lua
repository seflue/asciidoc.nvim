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

-- Loading the target buffer runs the ftplugin (treesitter, textobjects);
-- none of it may move the cursor away from the line the server returned.
T["goto definition into an unloaded file lands on the section"] = function()
    helpers.edit_with_lsp(child, "tests/fixtures/goto/index.adoc")
    local target = vim.g.asciidoc_nvim_root .. "/tests/fixtures/goto/target.adoc"
    expect.equality(child.fn.bufloaded(target), 0)
    child.api.nvim_win_set_cursor(0, { 3, 12 })
    child.lua("vim.lsp.buf.definition()")
    local arrived = child.lua_get(
        [[(function(path)
        return vim.wait(5000, function() return vim.api.nvim_buf_get_name(0) == path end, 20)
    end)(...)]],
        { target }
    )
    expect.equality(arrived, true)
    child.lua("vim.wait(200)")
    expect.equality(child.api.nvim_win_get_cursor(0), { 5, 0 })
end

return T
