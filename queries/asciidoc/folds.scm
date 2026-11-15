; folds.scm for asciidoc (block-level grammar)
; asciidoc.nvim — Parser: seflue/tree-sitter-asciidoc (main)

; Fold sections (heading + content)
(section) @fold

; Fold delimited blocks
(listing_block) @fold
(literal_block) @fold
(delimited_block) @fold
(open_block) @fold
(quoted_block) @fold

; Fold tables
(table_block) @fold
(ntable_block) @fold

; Fold lists
(list) @fold
