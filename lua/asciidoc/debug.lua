-- :AsciidocDebug: ask asciidoc-lsp how it resolves the cursor position
-- (`asciidoc.explainPosition`) and show the report as Markdown.

local M = {}

local function scalar(value)
    if value == nil or value == vim.NIL then
        return "`null`"
    end
    return "`" .. tostring(value) .. "`"
end

local function sorted_keys(tbl)
    local keys = vim.tbl_keys(tbl)
    table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)
    return keys
end

--- Append `value` as a nested bullet list, keys in sorted order so the
--- report reads the same on every run.
local function append_fields(lines, value, indent)
    for _, key in ipairs(sorted_keys(value)) do
        local child = value[key]
        if type(child) == "table" and next(child) ~= nil then
            lines[#lines + 1] = indent .. "- " .. key .. ":"
            append_fields(lines, child, indent .. "  ")
        elseif type(child) == "table" then
            lines[#lines + 1] = indent .. "- " .. key .. ": _empty_"
        else
            lines[#lines + 1] = indent .. "- " .. key .. ": " .. scalar(child)
        end
    end
end

local function append_section(lines, title, value, none)
    vim.list_extend(lines, { "## " .. title, "" })
    if type(value) == "table" then
        append_fields(lines, value, "")
    else
        lines[#lines + 1] = none
    end
    lines[#lines + 1] = ""
end

local function cell(value)
    if value == nil or value == vim.NIL then
        return ""
    end
    return (tostring(value):gsub("|", "\\|"))
end

local function append_known_attributes(lines, attributes)
    vim.list_extend(lines, { "## Known attributes", "" })
    if type(attributes) ~= "table" or #attributes == 0 then
        lines[#lines + 1] = "_None._"
        return
    end
    vim.list_extend(lines, { "| name | value | layer | source |", "| --- | --- | --- | --- |" })
    for _, attr in ipairs(attributes) do
        local source = ""
        if type(attr.source) == "table" then
            source = attr.source.file .. ":" .. attr.source.line
        end
        lines[#lines + 1] = string.format(
            "| %s | %s | %s | %s |",
            cell(attr.name),
            cell(attr.value),
            cell(attr.layer),
            cell(source)
        )
    end
end

--- Render an `asciidoc.explainPosition` report as Markdown lines.
--- `ctx` names the request: `path`, 1-based `line` and `col`.
function M.render(report, ctx)
    local lines = {
        "# AsciiDoc position report",
        "",
        string.format("`%s`, line %d, column %d", ctx.path, ctx.line, ctx.col),
        "",
    }
    append_section(lines, "Request", report.request, "_none_")
    append_section(lines, "Node", report.node, "_No AsciiDoc reference under the cursor._")
    append_section(lines, "Resolution", report.resolution, "_Nothing to resolve._")
    append_known_attributes(lines, report.known_attributes)
    return lines
end

local REPORT_NAME = "asciidoc://debug"

--- Return the report buffer, creating it on first use.
local function report_buffer()
    local buf = vim.fn.bufnr(REPORT_NAME)
    if buf ~= -1 then
        return buf
    end
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, REPORT_NAME)
    vim.bo[buf].bufhidden = "hide"
    vim.bo[buf].filetype = "markdown"
    return buf
end

--- Show `lines` in the report buffer and focus its window, opening a split
--- only when no window in the current tab shows it.
local function show(lines)
    local buf = report_buffer()
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    local tab_wins = vim.api.nvim_tabpage_list_wins(0)
    local win = vim.iter(vim.fn.win_findbuf(buf)):find(function(w)
        return vim.tbl_contains(tab_wins, w)
    end)
    if win then
        vim.api.nvim_set_current_win(win)
    else
        vim.cmd("botright split")
        vim.api.nvim_win_set_buf(0, buf)
    end
end

--- Request the report for the cursor position in the current buffer.
function M.run()
    local bufnr = vim.api.nvim_get_current_buf()
    local client = vim.lsp.get_clients({ bufnr = bufnr, name = "asciidoc" })[1]
    if not client then
        vim.notify("AsciidocDebug: asciidoc-lsp is not attached to this buffer", vim.log.levels.ERROR)
        return
    end
    local cursor = vim.api.nvim_win_get_cursor(0)
    local ctx = { path = vim.api.nvim_buf_get_name(bufnr), line = cursor[1], col = cursor[2] + 1 }
    local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
    client:request("workspace/executeCommand", {
        command = "asciidoc.explainPosition",
        arguments = { params },
    }, function(err, report)
        if err then
            vim.notify("AsciidocDebug: " .. err.message, vim.log.levels.ERROR)
            return
        end
        if type(report) ~= "table" then
            vim.notify("AsciidocDebug: asciidoc-lsp returned no report", vim.log.levels.ERROR)
            return
        end
        show(M.render(report, ctx))
    end, bufnr)
end

return M
