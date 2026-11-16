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

-- The plugin highlights with treesitter. Semantic tokens from the server
-- would sit on top of that (priority 125 against 100, :h lsp-semantic-highlight)
-- and restyle it, so they must not reach the buffer.
T["the server's semantic tokens do not highlight the buffer"] = function()
    -- Record what the server offered before the plugin's on_init drops it. An
    -- older server offers nothing, and the checks below would pass vacuously.
    child.lua([[
        local plugin_on_init = vim.lsp.config.asciidoc.on_init
        vim.g.server_offered_semantic_tokens = false
        vim.lsp.config("asciidoc", {
            on_init = function(client, init_result)
                vim.g.server_offered_semantic_tokens = init_result.capabilities.semanticTokensProvider ~= nil
                plugin_on_init(client, init_result)
            end,
        })
    ]])
    helpers.edit_with_lsp(child, "tests/fixtures/basic.adoc")
    expect.equality(child.g.server_offered_semantic_tokens, true)
    child.lua("vim.wait(500)")
    child.cmd("redraw!")
    local marks = child.lua_get([[(function()
        local count = 0
        for name, ns in pairs(vim.api.nvim_get_namespaces()) do
            if vim.startswith(name, "nvim.lsp.semantic_tokens") then
                count = count + #vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {})
            end
        end
        return count
    end)()]])
    expect.equality(marks, 0)
    expect.equality(
        child.lua_get([[vim.lsp.get_clients({ bufnr = 0, name = "asciidoc" })[1].server_capabilities.semanticTokensProvider == nil]]),
        true
    )
end

return T
