# asciidoc.nvim task runner
#
# Set ASCIIDOC_LSP_CMD to the asciidoc-lsp binary under test, e.g. from
# the asciidoc-lsp repo:
#   ASCIIDOC_LSP_CMD=$(just -f asciidoc-lsp/justfile bin-path) just -f asciidoc.nvim/justfile test

default:
    @just --list

# Clone mini.nvim (test framework) into deps/ if missing
deps:
    @test -d deps/mini.nvim || git clone --filter=blob:none --branch stable https://github.com/nvim-mini/mini.nvim deps/mini.nvim

# Run all tests headless (tests/test_*.lua)
test: deps
    nvim --headless --clean -u tests/minimal_init.lua -c "lua MiniTest.run()"

# Run one test file headless
test-file FILE: deps
    nvim --headless --clean -u tests/minimal_init.lua -c "lua MiniTest.run_file('{{FILE}}')"

# Open a file in a clean Neovim with only this plugin and the LSP
# (<Space> as leader, <leader>ca for code actions as in LazyVim)
fixture FILE:
    nvim --clean -u tests/minimal_init.lua --cmd "let mapleader = ' '" -c "nnoremap <leader>ca <Cmd>lua vim.lsp.buf.code_action()<CR>" {{FILE}}
