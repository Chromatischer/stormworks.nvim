; Stormworks section annotations
; Highlight ---@section and ---@endsection tags in comments

; Match ---@section lines
((comment) @stormworks.section
  (#match? @stormworks.section "^%-%-%-@section"))

; Match ---@endsection lines
((comment) @stormworks.endsection
  (#match? @stormworks.endsection "^%-%-%-@endsection"))
