# Marked sections in a target's global instructions file, keyed by a tag ("mcp:<name>", "instruction:<name>").

section_start() { echo "<!-- harness:$1 -->"; }
section_end() { echo "<!-- /harness:$1 -->"; }

has_section() { # tag target
  [[ -f ${INSTRUCTION_FILES[$2]} ]] && grep -qxF "$(section_start "$1")" "${INSTRUCTION_FILES[$2]}"
}

section_names() { # kind target -> names of installed sections of that kind
  local file=${INSTRUCTION_FILES[$2]}
  [[ -f $file ]] && sed -n "s/^<!-- harness:$1:\(.*\) -->$/\1/p" "$file"
}

installed_section() { # tag target -> section text without the markers
  local file=${INSTRUCTION_FILES[$2]}
  [[ -f $file ]] || return 0
  awk -v start="$(section_start "$1")" -v end="$(section_end "$1")" '$0 == end { inside = 0 } inside; $0 == start { inside = 1 }' "$file"
}

add_section() { # tag text_file target
  local file=${INSTRUCTION_FILES[$3]}
  remove_section "$1" "$3"
  mkdir -p "$(dirname "$file")"
  [[ -s $file ]] && echo >>"$file"
  { section_start "$1"; cat "$2"; section_end "$1"; } >>"$file"
}

remove_section() { # tag target; also drops the blank line that add_section put before it
  local file=${INSTRUCTION_FILES[$2]}
  [[ -f $file ]] || return 0
  awk -v start="$(section_start "$1")" -v end="$(section_end "$1")" '
    $0 == start { inside = 1; blank = 0; next }
    inside { if ($0 == end) inside = 0; next }
    blank { print ""; blank = 0 }
    $0 == "" { blank = 1; next }
    { print }
    END { if (blank) print "" }' "$file" >"$file.tmp" && mv "$file.tmp" "$file"
}
