; injections.scm for asciidoc (block-level grammar)
; asciidoc.nvim — Parser: cathaysia/tree-sitter-asciidoc

; No asciidoc_inline injection: the grammar parses inline content (monospace,
; emphasis, xref, inline_macro, ...) directly inside (line) nodes.

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
