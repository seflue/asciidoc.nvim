# asciidoc.nvim task runner
#
# Set ASCIIDOC_LSP_CMD to the asciidoc-lsp binary under test, e.g. from
# the asciidoc-lsp repo:
#   ASCIIDOC_LSP_CMD=$(just -f asciidoc-lsp/justfile bin-path) just -f asciidoc.nvim/justfile test

# Grammar commit the bundled queries were taken from
grammar_rev := "5098fa6"

default:
    @just --list

# Clone mini.nvim (test framework) into deps/ if missing
deps:
    @test -d deps/mini.nvim || git clone --filter=blob:none --branch stable https://github.com/nvim-mini/mini.nvim deps/mini.nvim

# Build the asciidoc parsers into deps/site/ if missing (needs the tree-sitter CLI)
parsers:
    @test -d deps/tree-sitter-asciidoc || git clone --filter=blob:none https://github.com/seflue/tree-sitter-asciidoc deps/tree-sitter-asciidoc
    @git -C deps/tree-sitter-asciidoc checkout --quiet --detach {{grammar_rev}}
    @mkdir -p deps/site/parser
    @test -f deps/site/parser/asciidoc.so || tree-sitter build -o deps/site/parser/asciidoc.so deps/tree-sitter-asciidoc/tree-sitter-asciidoc
    @test -f deps/site/parser/asciidoc_inline.so || tree-sitter build -o deps/site/parser/asciidoc_inline.so deps/tree-sitter-asciidoc/tree-sitter-asciidoc_inline

# Run all tests headless (tests/test_*.lua)
test: deps parsers
    nvim --headless --clean -u tests/minimal_init.lua -c "lua MiniTest.run()"

# Run one test file headless
test-file FILE: deps parsers
    nvim --headless --clean -u tests/minimal_init.lua -c "lua MiniTest.run_file('{{FILE}}')"

# Open a file in a clean Neovim with only this plugin and the LSP
# (<Space> as leader, <leader>ca for code actions as in LazyVim)
fixture FILE: parsers
    nvim --clean -u tests/minimal_init.lua --cmd "let mapleader = ' '" -c "nnoremap <leader>ca <Cmd>lua vim.lsp.buf.code_action()<CR>" {{FILE}}
