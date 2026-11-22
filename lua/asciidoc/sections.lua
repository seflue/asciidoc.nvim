-- Sections of an AsciiDoc buffer as the bundled textobjects query captures
-- them (`@section.outer` / `@section.inner`), shared by the section text
-- objects and the section motions.

local M = {}

--- Return `{ start_row, end_row }` (0-based, end exclusive) for a capture
--- spanning `first` to `last`.
local function line_span(first, last)
    local srow = first:range()
    local _, _, erow, ecol = last:range()
    return { srow, ecol == 0 and erow or erow + 1 }
end

--- All sections of `bufnr` in document order. Each entry has `node`,
--- `outer`, `title` (0-based row of the title line), `parent` (the
--- enclosing entry or nil) and, unless the section is only a title, `inner`.
function M.list(bufnr)
    local parser = vim.treesitter.get_parser(bufnr, "asciidoc", { error = false })
    local query = vim.treesitter.query.get("asciidoc", "textobjects")
    if not parser or not query then
        return {}
    end
    local by_id = {}
    for _, match in query:iter_matches(parser:parse()[1]:root(), bufnr) do
        for id, nodes in pairs(match) do
            local capture = query.captures[id]
            if capture == "section.outer" or capture == "section.inner" then
                local section = capture == "section.outer" and nodes[1] or nodes[1]:parent()
                local entry = by_id[section:id()] or { node = section, outer = line_span(section, section) }
                by_id[section:id()] = entry
                if capture == "section.inner" then
                    entry.inner = line_span(nodes[1], nodes[#nodes])
                end
            end
        end
    end
    local list = {}
    for _, entry in pairs(by_id) do
        for child in entry.node:iter_children() do
            if child:type():match("^title%d$") then
                entry.title = child:range()
            end
        end
        local up = entry.node:parent()
        while up and not by_id[up:id()] do
            up = up:parent()
        end
        entry.parent = up and by_id[up:id()]
        list[#list + 1] = entry
    end
    table.sort(list, function(a, b)
        return a.outer[1] < b.outer[1]
    end)
    return list
end

--- Sections containing 0-based `row`, innermost first.
function M.at(bufnr, row)
    local found = {}
    for _, entry in ipairs(M.list(bufnr)) do
        if row >= entry.outer[1] and row < entry.outer[2] then
            table.insert(found, 1, entry)
        end
    end
    return found
end

return M
