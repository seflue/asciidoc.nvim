local helpers = require("helpers")
local expect = MiniTest.expect

local child = helpers.new_child()

local T = MiniTest.new_set({
    hooks = {
        pre_case = child.setup,
        post_once = child.stop,
    },
})

--- A fresh canonical tmp folder with `files` (paths relative to it) created:
--- a trailing `/` makes a folder, anything else an empty file.
local function tree(files)
    local tmp = vim.fn.tempname()
    vim.fn.mkdir(tmp, "p")
    local root = assert(vim.uv.fs_realpath(tmp))
    for _, file in ipairs(files) do
        if file:sub(-1) == "/" then
            vim.fn.mkdir(root .. "/" .. file, "p")
        else
            vim.fn.mkdir(vim.fs.dirname(root .. "/" .. file), "p")
            vim.fn.writefile({}, root .. "/" .. file)
        end
    end
    return root
end

--- The root `asciidoc.root.find` picks for `path` with the cwd `cwd`.
local function find(path, cwd)
    return child.lua_get("require('asciidoc.root').find(...)", { path, cwd })
end

T["a VCS root wins over a config file in a subfolder"] = function()
    for _, vcs in ipairs({ ".git/", ".jj/", ".hg/" }) do
        local root = tree({ vcs, "docs/ADRs/.asciidoctorconfig.adoc", "docs/ADRs/adr.adoc" })
        expect.equality(find(root .. "/docs/ADRs/adr.adoc", "/"), root)
    end
end

T["without VCS, the cwd holding the file is the root"] = function()
    local root = tree({ "docs/ADRs/.asciidoctorconfig", "docs/ADRs/adr.adoc" })
    expect.equality(find(root .. "/docs/ADRs/adr.adoc", root), root)
end

T["without VCS and outside the cwd, the nearest config folder is the root"] = function()
    local root = tree({ "docs/.asciidoctorconfig", "docs/ADRs/.asciidoctorconfig.adoc", "docs/ADRs/adr.adoc" })
    local other = tree({})
    expect.equality(find(root .. "/docs/ADRs/adr.adoc", other), root .. "/docs/ADRs")
end

T["with nothing to go by, the file's folder is the root"] = function()
    local root = tree({ "docs/adr.adoc" })
    local other = tree({})
    expect.equality(find(root .. "/docs/adr.adoc", other), root .. "/docs")
end

T["the home folder as cwd is no root"] = function()
    -- A cwd of `~` would make the server scan the whole home folder.
    local root = tree({ "docs/adr.adoc" })
    child.lua("vim.env.HOME = ...", { root })
    expect.equality(find(root .. "/docs/adr.adoc", root), root .. "/docs")
end

T["the file system root as cwd is no root"] = function()
    local root = tree({ "docs/adr.adoc" })
    expect.equality(find(root .. "/docs/adr.adoc", "/"), root .. "/docs")
end

T["the client config takes its root from the module"] = function()
    local root = tree({ ".git/", "docs/ADRs/.asciidoctorconfig.adoc", "docs/ADRs/adr.adoc" })
    child.cmd("edit " .. root .. "/docs/ADRs/adr.adoc")
    local found = child.lua_get([[(function()
        local result
        vim.lsp.config.asciidoc.root_dir(0, function(dir) result = dir end)
        return result
    end)()]])
    expect.equality(found, root)
end

return T
