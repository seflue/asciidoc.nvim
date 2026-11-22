; folds.scm for asciidoc (block-level grammar)
; asciidoc.nvim — Parser: seflue/tree-sitter-asciidoc (main)

; Fold sections from the title on: an anchor or attribute line above it
; stays visible, so a closed fold shows the title
(section
  [(title1) (title2) (title3) (title4) (title5)] @fold
  (_)* @fold .)

; Fold delimited blocks
(listing_block) @fold
(literal_block) @fold
(delimited_block) @fold
(open_block) @fold
(quoted_block) @fold
(quoted_md_block) @fold
(sidebar_block) @fold
(passthrough_block) @fold
(block_comment) @fold

; Fold tables
(table_block) @fold
(ntable_block) @fold
(csv_table_block) @fold
(dsv_table_block) @fold

; Fold lists
(list) @fold
(description_list) @fold
