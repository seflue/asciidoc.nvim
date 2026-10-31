vim.opt_local.iskeyword:append("-") -- word-motions over hyphens (anchor IDs, attribute names)
vim.opt_local.iskeyword:append(":") -- for attribute names
vim.opt_local.commentstring = "// %s" -- AsciiDoc comment syntax
vim.opt_local.spell = true -- prose editing
vim.opt_local.wrap = true -- soft-wrap for prose
