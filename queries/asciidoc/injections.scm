; injections.scm for asciidoc (block-level grammar)
; asciidoc.nvim — Parser: cathaysia/tree-sitter-asciidoc

; --- Inline injection into paragraph lines ---
; The block-level parser produces (line) nodes inside paragraphs without
; decomposing inline content. Inject asciidoc_inline to parse bold, italic,
; inline macros (image:, kbd:, etc.), xrefs, and attribute references.
; Paragraphs
(paragraph
  (line) @injection.content
  (#set! injection.language "asciidoc_inline"))

; List items (ordered, unordered, checked, callout)
(ordered_list_item
  (line) @injection.content
  (#set! injection.language "asciidoc_inline"))

(unordered_list_item
  (line) @injection.content
  (#set! injection.language "asciidoc_inline"))

(checked_list_item
  (line) @injection.content
  (#set! injection.language "asciidoc_inline"))

(callout_list_item
  (line) @injection.content
  (#set! injection.language "asciidoc_inline"))

; Indented blocks (e.g. nested list items parsed as ident_block)
; ident_block_line has no named content child — inject the whole node.
; The ident_marker (whitespace + bullet) is harmless for the inline parser.
((ident_block_line) @injection.content
  (#set! injection.language "asciidoc_inline"))

; --- Source Block Language Injection ---
; Tree structure (verified via :InspectTree):
;   (section_block
;     (element_attr
;       (attr_value))          ; "source,rust" — single node, comma-separated
;     (listing_block
;       (listing_block_body))) ; code content
;
; element_attr and listing_block are siblings under section_block.
; attr_value contains the full string "source,<lang>".
; We use #match? with regex to extract the language.

; Rust
(section_block
  (element_attr
    (attr_value) @_attr
    (#match? @_attr "^source,rust"))
  (listing_block
    (listing_block_body) @injection.content
    (#set! injection.language "rust")))

; Python
(section_block
  (element_attr
    (attr_value) @_attr
    (#match? @_attr "^source,python"))
  (listing_block
    (listing_block_body) @injection.content
    (#set! injection.language "python")))

; JavaScript
(section_block
  (element_attr
    (attr_value) @_attr
    (#match? @_attr "^source,javascript"))
  (listing_block
    (listing_block_body) @injection.content
    (#set! injection.language "javascript")))

; TypeScript
(section_block
  (element_attr
    (attr_value) @_attr
    (#match? @_attr "^source,typescript"))
  (listing_block
    (listing_block_body) @injection.content
    (#set! injection.language "typescript")))

; Lua
(section_block
  (element_attr
    (attr_value) @_attr
    (#match? @_attr "^source,lua"))
  (listing_block
    (listing_block_body) @injection.content
    (#set! injection.language "lua")))

; Java
(section_block
  (element_attr
    (attr_value) @_attr
    (#match? @_attr "^source,java$"))
  (listing_block
    (listing_block_body) @injection.content
    (#set! injection.language "java")))

; C
(section_block
  (element_attr
    (attr_value) @_attr
    (#match? @_attr "^source,c$"))
  (listing_block
    (listing_block_body) @injection.content
    (#set! injection.language "c")))

; C++
(section_block
  (element_attr
    (attr_value) @_attr
    (#match? @_attr "^source,cpp"))
  (listing_block
    (listing_block_body) @injection.content
    (#set! injection.language "cpp")))

; Go
(section_block
  (element_attr
    (attr_value) @_attr
    (#match? @_attr "^source,go$"))
  (listing_block
    (listing_block_body) @injection.content
    (#set! injection.language "go")))

; Bash/Shell
(section_block
  (element_attr
    (attr_value) @_attr
    (#match? @_attr "^source,bash"))
  (listing_block
    (listing_block_body) @injection.content
    (#set! injection.language "bash")))

(section_block
  (element_attr
    (attr_value) @_attr
    (#match? @_attr "^source,sh$"))
  (listing_block
    (listing_block_body) @injection.content
    (#set! injection.language "bash")))

; YAML
(section_block
  (element_attr
    (attr_value) @_attr
    (#match? @_attr "^source,yaml"))
  (listing_block
    (listing_block_body) @injection.content
    (#set! injection.language "yaml")))

; TOML
(section_block
  (element_attr
    (attr_value) @_attr
    (#match? @_attr "^source,toml"))
  (listing_block
    (listing_block_body) @injection.content
    (#set! injection.language "toml")))

; JSON
(section_block
  (element_attr
    (attr_value) @_attr
    (#match? @_attr "^source,json"))
  (listing_block
    (listing_block_body) @injection.content
    (#set! injection.language "json")))

; XML/HTML
(section_block
  (element_attr
    (attr_value) @_attr
    (#match? @_attr "^source,xml"))
  (listing_block
    (listing_block_body) @injection.content
    (#set! injection.language "xml")))

(section_block
  (element_attr
    (attr_value) @_attr
    (#match? @_attr "^source,html"))
  (listing_block
    (listing_block_body) @injection.content
    (#set! injection.language "html")))

; SQL
(section_block
  (element_attr
    (attr_value) @_attr
    (#match? @_attr "^source,sql"))
  (listing_block
    (listing_block_body) @injection.content
    (#set! injection.language "sql")))

; Ruby
(section_block
  (element_attr
    (attr_value) @_attr
    (#match? @_attr "^source,ruby"))
  (listing_block
    (listing_block_body) @injection.content
    (#set! injection.language "ruby")))
