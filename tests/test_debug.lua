local expect = MiniTest.expect

local T = MiniTest.new_set()

local ctx = { path = "/doc/a.adoc", line = 5, col = 3 }

T["render"] = MiniTest.new_set()

T["render"]["shows request, node, resolution and known attributes"] = function()
    local report = {
        request = {
            raw_path = "/doc/a.adoc",
            canonical_path = "/real/a.adoc",
            paths_differ = true,
            canonicalize_error = vim.NIL,
        },
        node = { kind = "attribute_ref", line = 5, fields = { name = "foo" } },
        resolution = {
            name = "foo",
            scopes = { { scope = "a.adoc", value = "a|b", definition = vim.NIL } },
        },
        known_attributes = {
            {
                scope = "a.adoc",
                name = "foo",
                value = "a|b",
                origin = "document",
                source = { file = "/doc/a.adoc", line = 2 },
            },
            { scope = "a.adoc", name = "doctype", value = "article", origin = "builtin", source = vim.NIL },
        },
    }

    expect.equality(require("asciidoc.debug").render(report, ctx), {
        "# AsciiDoc position report",
        "",
        "`/doc/a.adoc`, line 5, column 3",
        "",
        "## Request",
        "",
        "- canonical_path: `/real/a.adoc`",
        "- canonicalize_error: `null`",
        "- paths_differ: `true`",
        "- raw_path: `/doc/a.adoc`",
        "",
        "## Node",
        "",
        "- fields:",
        "  - name: `foo`",
        "- kind: `attribute_ref`",
        "- line: `5`",
        "",
        "## Resolution",
        "",
        "- name: `foo`",
        "- scopes:",
        "  - 1:",
        "    - definition: `null`",
        "    - scope: `a.adoc`",
        "    - value: `a|b`",
        "",
        "## Known attributes",
        "",
        "| scope | name | value | origin | source |",
        "| --- | --- | --- | --- | --- |",
        "| a.adoc | foo | a\\|b | document | /doc/a.adoc:2 |",
        "| a.adoc | doctype | article | builtin |  |",
    })
end

T["render"]["says so when no reference is under the cursor"] = function()
    local report = {
        request = { raw_path = "/doc/a.adoc" },
        node = vim.NIL,
        resolution = vim.NIL,
        known_attributes = {},
    }

    local lines = require("asciidoc.debug").render(report, ctx)
    expect.equality(vim.list_slice(lines, 9), {
        "## Node",
        "",
        "_No AsciiDoc reference under the cursor._",
        "",
        "## Resolution",
        "",
        "_Nothing to resolve._",
        "",
        "## Known attributes",
        "",
        "_None._",
    })
end

-- A report line may not contain a newline: nvim_buf_set_lines rejects
-- such items. The server can send names that span lines.
T["render"]["escapes newlines in table cells"] = function()
    local report = {
        known_attributes = {
            { scope = "a.adoc", name = "to\n// Expected", value = "a\r\nb", origin = "document", source = vim.NIL },
        },
    }

    local lines = require("asciidoc.debug").render(report, ctx)
    expect.equality(lines[#lines], "| a.adoc | to\\n// Expected | a\\r\\nb | document |  |")
end

-- GFM reads `\\|` as an escaped backslash and a cell boundary, so a value
-- ending in a backslash would split its row unless the backslash is
-- escaped too.
T["render"]["escapes backslashes in table cells"] = function()
    local report = {
        known_attributes = {
            { scope = "a.adoc", name = "dir", value = "C:\\", origin = "document", source = vim.NIL },
        },
    }

    local lines = require("asciidoc.debug").render(report, ctx)
    expect.equality(lines[#lines], "| a.adoc | dir | C:\\\\ | document |  |")
end

T["render"]["escapes newlines in field values"] = function()
    local report = { resolution = { name = "to\n// Expected" } }

    local lines = require("asciidoc.debug").render(report, ctx)
    expect.equality(vim.list_slice(lines, 13, 15), {
        "## Resolution",
        "",
        "- name: `to\\n// Expected`",
    })
end

local helpers = require("helpers")
local child = helpers.new_child()

--- Put the cursor on `text` in the child's buffer, run :AsciidocDebug and
--- return the report buffer's lines once the report for that line arrived.
local function debug_at(text)
    local row = child.fn.search(vim.fn.escape(text, "\\[]"), "w")
    child.api.nvim_win_set_cursor(0, { row, child.fn.col(".") })
    child.cmd("AsciidocDebug")
    local header = string.format(", line %d, column ", row)
    local ok = child.lua_get(
        [[(function(header)
            return vim.wait(10000, function()
                local buf = vim.fn.bufnr("asciidoc://debug")
                if buf == -1 then
                    return false
                end
                local third = vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1] or ""
                return third:find(header, 1, true) ~= nil
            end, 20)
        end)(...)]],
        { header }
    )
    if not ok then
        error("no report for line " .. row)
    end
    return child.api.nvim_buf_get_lines(child.fn.bufnr("asciidoc://debug"), 0, -1, false)
end

T[":AsciidocDebug"] = MiniTest.new_set({
    hooks = {
        pre_case = function()
            child.setup()
            helpers.edit_with_lsp(child, "tests/fixtures/debug.adoc")
        end,
        post_once = child.stop,
    },
})

T[":AsciidocDebug"]["reports an attribute reference"] = function()
    local lines = debug_at("{product}")
    expect.equality(vim.tbl_contains(lines, "- kind: `attribute_ref`"), true)
    expect.equality(vim.tbl_contains(lines, "    - value: `Widget`"), true)
end

T[":AsciidocDebug"]["reports an xref"] = function()
    local lines = debug_at("xref:basic")
    expect.equality(vim.tbl_contains(lines, "- kind: `xref`"), true)
    expect.equality(vim.tbl_contains(lines, "    - error: `null`"), true)
end

T[":AsciidocDebug"]["reports an include"] = function()
    local lines = debug_at("include::basic")
    expect.equality(vim.tbl_contains(lines, "- kind: `include`"), true)
    expect.equality(vim.tbl_contains(lines, "    - exists: `true`"), true)
end

T[":AsciidocDebug"]["reports plain text"] = function()
    local lines = debug_at("Plain text")
    expect.equality(vim.tbl_contains(lines, "_No AsciiDoc reference under the cursor._"), true)
    expect.equality(vim.tbl_contains(lines, "## Request"), true)
end

T[":AsciidocDebug"]["reuses one scratch buffer and window"] = function()
    debug_at("{product}")
    local buf = child.fn.bufnr("asciidoc://debug")
    expect.equality(child.api.nvim_get_current_buf(), buf)
    expect.equality(child.api.nvim_get_option_value("buftype", { buf = buf }), "nofile")
    child.cmd("wincmd p")

    local lines = debug_at("xref:basic")
    expect.equality(child.fn.bufnr("asciidoc://debug"), buf)
    expect.equality(child.fn.win_findbuf(buf), { child.api.nvim_get_current_win() })
    expect.equality(#child.api.nvim_list_wins(), 2)
    expect.equality(vim.tbl_contains(lines, "- kind: `attribute_ref`"), false)
end

T[":AsciidocDebug"]["reuses the report window of the current tab"] = function()
    debug_at("{product}")
    child.cmd("tabnew " .. vim.fn.fnameescape(vim.g.asciidoc_nvim_root .. "/tests/fixtures/debug.adoc"))
    -- A different line than the previous call: debug_at waits for its header.
    debug_at("include::basic")
    child.cmd("wincmd p")

    debug_at("xref:basic")
    expect.equality(#child.api.nvim_tabpage_list_wins(0), 2)
end

return T
