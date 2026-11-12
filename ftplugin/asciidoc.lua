vim.opt_local.iskeyword:append("-") -- word-motions over hyphens (anchor IDs, attribute names)
vim.opt_local.iskeyword:append(":") -- for attribute names
vim.opt_local.commentstring = "// %s" -- AsciiDoc comment syntax
vim.opt_local.spell = true -- prose editing
vim.opt_local.wrap = true -- soft-wrap for prose
pcall(vim.treesitter.start) -- also limits spell to @spell regions
if require("asciidoc.config").textobjects.enable ~= false then
    require("asciidoc.textobjects").attach(0)
end
if require("asciidoc.config").conceal.enable ~= false then
    require("asciidoc.conceal").attach(0)
end
