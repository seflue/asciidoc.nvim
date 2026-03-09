; highlights.scm for asciidoc (block-level grammar)
; asciidoc.nvim — Parser: cathaysia/tree-sitter-asciidoc

; =============================================================================
; --- Section Titles ---
; =============================================================================

(document_title) @markup.heading.1
(title1) @markup.heading.2
(title2) @markup.heading.3
(title3) @markup.heading.4
(title4) @markup.heading.5
(title5) @markup.heading.6

; Title markers (= signs)
(title_h0_marker) @punctuation.special

; =============================================================================
; --- Document Attributes ---
; =============================================================================

(document_attr
  (attr_name) @property
  (line) @string)

; =============================================================================
; --- Block Macros ---
; =============================================================================

; include::, image::, video::, etc.
(block_macro
  (block_macro_name) @function.macro
  (target) @string.special.path)

; Block macro attribute list: [alt text, width, ...]
(block_macro_attr
  (attribute_name) @string)

; =============================================================================
; --- Admonitions ---
; =============================================================================

(admonition) @markup.note

; =============================================================================
; --- Block Delimiters ---
; =============================================================================

(listing_block_start_marker) @punctuation.delimiter
(listing_block_end_marker) @punctuation.delimiter
(literal_block_marker) @punctuation.delimiter

; =============================================================================
; --- Block Titles and Metadata ---
; =============================================================================

; .Block Title
(block_title) @markup.italic

; [source,rust], [cols="1,2", options="header"] etc.
(element_attr
  (element_attr_marker) @punctuation.special
  (attr_value) @attribute)

; =============================================================================
; --- Lists ---
; =============================================================================

; Only highlight the marker (. * - [x]), not the whole item
(unordered_list_marker) @markup.list
(ordered_list_marker) @markup.list
(checked_list_marker) @markup.list
(callout_list_marker) @markup.list

; =============================================================================
; --- Tables ---
; =============================================================================

; |=== delimiter
(table_block_marker) @punctuation.special

; | cell separator (anonymous node inside table_cell)
(table_cell
  "|" @punctuation.special)

; =============================================================================
; --- Literal / Listing Block Body ---
; =============================================================================
; Only highlight as raw if no language injection takes over

(listing_block_body) @markup.raw.block
(literal_block_body) @markup.raw.block

; =============================================================================
; --- Author / Revision ---
; =============================================================================

(author) @string.special
(revision_line) @string.special

; =============================================================================
; --- Hard line break ---
; =============================================================================

(hard_wrap) @punctuation.special

; =============================================================================
; --- Breaks (page break <<<, thematic break ---) ---
; =============================================================================

(breaks_marker) @punctuation.special
