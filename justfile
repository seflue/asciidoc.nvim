# asciidoc.nvim task runner
#
# test and test-file need ASCIIDOC_LSP_CMD set to the asciidoc-lsp binary
# under test (they abort without it), e.g. from the asciidoc-lsp repo:
#   ASCIIDOC_LSP_CMD=$(just -f asciidoc-lsp/justfile bin-path) just -f asciidoc.nvim/justfile test

# Grammar the bundled queries are written for, read from
# lua/asciidoc/grammar.lua (the single source of truth)
grammar_url := `sed -n 's/^ *url = "\(.*\)",$/\1/p' lua/asciidoc/grammar.lua`
grammar_rev := `sed -n 's/^ *revision = "\([0-9a-f]*\)",$/\1/p' lua/asciidoc/grammar.lua`

default:
    @just --list

# Clone mini.nvim (test framework) into deps/ if missing
deps:
    @test -d deps/mini.nvim || git clone --filter=blob:none --branch stable https://github.com/nvim-mini/mini.nvim deps/mini.nvim

# Build the asciidoc parsers into deps/site/ if missing or built from
# another grammar_rev (needs the tree-sitter CLI)
parsers:
    @test -d deps/tree-sitter-asciidoc || git clone --filter=blob:none {{grammar_url}} deps/tree-sitter-asciidoc
    @git -C deps/tree-sitter-asciidoc cat-file -e {{grammar_rev}}^{commit} 2>/dev/null || git -C deps/tree-sitter-asciidoc fetch --quiet origin
    @git -C deps/tree-sitter-asciidoc checkout --quiet --detach {{grammar_rev}}
    @mkdir -p deps/site/parser
    @test "$(cat deps/site/parser/grammar_rev 2>/dev/null)" = "{{grammar_rev}}" || rm -f deps/site/parser/asciidoc.so deps/site/parser/asciidoc_inline.so deps/site/parser/grammar_rev
    @test -f deps/site/parser/asciidoc.so || tree-sitter build -o deps/site/parser/asciidoc.so deps/tree-sitter-asciidoc/tree-sitter-asciidoc
    @test -f deps/site/parser/asciidoc_inline.so || tree-sitter build -o deps/site/parser/asciidoc_inline.so deps/tree-sitter-asciidoc/tree-sitter-asciidoc_inline
    @echo "{{grammar_rev}}" > deps/site/parser/grammar_rev

# Abort unless ASCIIDOC_LSP_CMD names the server under test, so the suite
# never falls back to an outdated asciidoc-lsp from PATH
[private]
require-lsp-cmd:
    @test -n "${ASCIIDOC_LSP_CMD:-}" || { echo "ASCIIDOC_LSP_CMD is not set: point it at the asciidoc-lsp binary under test (see the top of this justfile)" >&2; exit 1; }

# Run all tests headless (tests/test_*.lua)
test: require-lsp-cmd deps parsers
    nvim --headless --clean -u tests/minimal_init.lua -c "lua MiniTest.run()"

# Run one test file headless
test-file FILE: require-lsp-cmd deps parsers
    nvim --headless --clean -u tests/minimal_init.lua -c "lua MiniTest.run_file('{{FILE}}')"

# Open a file in a clean Neovim with only this plugin and the LSP
# (<Space> as leader, <leader>ca for code actions as in LazyVim)
fixture FILE: parsers
    nvim --clean -u tests/minimal_init.lua --cmd "let mapleader = ' '" -c "nnoremap <leader>ca <Cmd>lua vim.lsp.buf.code_action()<CR>" {{FILE}}

# Cut a release: bump is patch, minor or major (gate: test on main, needs ASCIIDOC_LSP_CMD)
release bump:
    RELEASE_LINT_CMD=true scripts/release.sh {{bump}}
