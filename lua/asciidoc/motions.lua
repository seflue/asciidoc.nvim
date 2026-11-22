-- Section motions `]]` / `[[` / `][` / `[]` / `[u` / `]u`, built on the sections
-- the bundled textobjects query captures, like the `iS` / `aS` objects.

local sections = require("asciidoc.sections")

local M = {}

--- Whether `entry` is a discrete heading, which Asciidoctor does not read
--- as a section although the grammar nests it like one.
local function is_discrete(entry, bufnr)
    for child in entry.node:iter_children() do
        if child:type() == "element_attr" then
            for style in child:iter_children() do
                local first = style:named_child(0)
                if first and first:type() == "block_style" then
                    local name = vim.treesitter.get_node_text(first, bufnr)
                    if name == "discrete" or name == "float" then
                        return true
                    end
                end
            end
        end
    end
    return false
end

--- The sections that are motion targets, in document order. Each entry
--- gets `up`, the nearest enclosing target, past any discrete heading. The
--- discrete headings the grammar nests like sections are kept in
--- `list.discrete`.
local function targets(bufnr)
    local list = { discrete = {} }
    for _, entry in ipairs(sections.list(bufnr)) do
        if is_discrete(entry, bufnr) then
            list.discrete[#list.discrete + 1] = entry
        else
            local up = entry.parent
            while up and is_discrete(up, bufnr) do
                up = up.parent
            end
            entry.up = up
            list[#list + 1] = entry
        end
    end
    return list
end

--- The innermost target around 0-based `row`, or nil. Text after a
--- discrete heading belongs, as Asciidoctor reads it, to the section whose
--- content was open before the heading: the last target starting earlier.
local function around(list, row)
    local found
    for _, entries in ipairs({ list, list.discrete }) do
        for _, entry in ipairs(entries) do
            local contains = row >= entry.outer[1] and row < entry.outer[2]
            if contains and (not found or entry.outer[1] > found.outer[1]) then
                found = entry
            end
        end
    end
    if found and vim.tbl_contains(list.discrete, found) then
        local before
        for _, entry in ipairs(list) do
            if entry.outer[1] < found.outer[1] then
                before = entry
            end
        end
        found = before
    end
    return found
end

--- The `count`-th entry of `list` after (`step` 1) or before (`step` -1)
--- `from` that shares its `up`, or nil.
local function sibling(list, from, step, count)
    if not from then
        return nil
    end
    local index
    for i, entry in ipairs(list) do
        if entry == from then
            index = i
        end
    end
    for i = index + step, step > 0 and #list or 1, step do
        if list[i].up == from.up then
            count = count - 1
            if count == 0 then
                return list[i]
            end
        end
    end
end

local resolvers = {}

function resolvers.next_sibling(list, row, count)
    return sibling(list, around(list, row), 1, count)
end

function resolvers.prev_sibling(list, row, count)
    return sibling(list, around(list, row), -1, count)
end

--- `row`, or the start of the section whose head (the title and the
--- anchors and attributes above it) holds `row`.
local function head_start(list, row)
    for _, entry in ipairs(list) do
        if row >= entry.outer[1] and row <= entry.title then
            return entry.outer[1]
        end
    end
    return row
end

function resolvers.next(list, row, count)
    row = head_start(list, row)
    for _, entry in ipairs(list) do
        if entry.outer[1] > row then
            count = count - 1
            if count == 0 then
                return entry
            end
        end
    end
end

function resolvers.prev(list, row, count)
    row = head_start(list, row)
    for i = #list, 1, -1 do
        if list[i].outer[1] < row then
            count = count - 1
            if count == 0 then
                return list[i]
            end
        end
    end
end

function resolvers.parent(list, row, count)
    local target = around(list, row)
    -- on the title or the metadata above it the section itself is not out
    if target and row <= target.title then
        target = target.up
    end
    for _ = 2, count do
        target = target and target.up
    end
    return target
end

function resolvers.next_parent(list, row, count)
    return sibling(list, resolvers.parent(list, row, count), 1, 1)
end

--- The section `kind` names from 0-based `row`, `count` times, or nil.
local function resolve(kind, row, count)
    return resolvers[kind](targets(0), row, count)
end

local function no_target()
    -- An error from `<Cmd>` makes Neovim drop a pending operator.
    vim.api.nvim_echo({ { "No section here" } }, true, { err = true })
end

--- Jump to the title line of the section `kind` names from the cursor. A
--- pending operator ends at the start of the section instead, so metadata
--- above the title stays out of an exclusive `d]]`.
function M.jump(kind)
    local target = resolve(kind, vim.fn.line(".") - 1, vim.v.count1)
    if not target then
        return no_target()
    end
    local pending = vim.fn.mode(true):find("^no") ~= nil
    vim.cmd("normal! m'")
    vim.api.nvim_win_set_cursor(0, { (pending and target.outer[1] or target.title) + 1, 0 })
end

local names = {
    next = "Next section",
    prev = "Previous section",
    next_sibling = "Next sibling section",
    prev_sibling = "Previous sibling section",
    parent = "Parent section",
    next_parent = "Next section at the parent's level",
}

--- Map the section motions for `bufnr` to the keys in `motions.keys`,
--- skipping a key set to false.
function M.attach(bufnr)
    for kind, lhs in pairs(require("asciidoc.config").motions.keys) do
        if lhs then
            vim.keymap.set({ "n", "x", "o" }, lhs, function()
                M.jump(kind)
            end, { buffer = bufnr, desc = names[kind] })
        end
    end
end

return M
