#!/usr/bin/env bats

setup() {
    DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
    MOD_DIR="$DOTFILES_DIR/modules/claude-settings"
    FIXTURES="$MOD_DIR/tests/fixtures"
    STRATEGIES="$MOD_DIR/lib/strategies.jq"
}

@test "shallow-merge: overlay wins per top-level key" {
    actual=$(jq -n --slurpfile a "$FIXTURES/shallow-merge-base.json" \
                   --slurpfile b "$FIXTURES/shallow-merge-overlay.json" \
                   "include \"strategies\" {search: \"$MOD_DIR/lib\"}; shallow_merge(\$a[0]; \$b[0])")
    expected=$(cat "$FIXTURES/shallow-merge-expected.json")
    [ "$(echo "$actual" | jq -S .)" = "$(echo "$expected" | jq -S .)" ]
}

@test "concat-dedupe: array append + dedupe" {
    actual=$(jq -n --slurpfile a "$FIXTURES/concat-dedupe-base.json" \
                   --slurpfile b "$FIXTURES/concat-dedupe-overlay.json" \
                   "include \"strategies\" {search: \"$MOD_DIR/lib\"}; concat_dedupe(\$a[0]; \$b[0])")
    expected=$(cat "$FIXTURES/concat-dedupe-expected.json")
    [ "$(echo "$actual" | jq -S .)" = "$(echo "$expected" | jq -S .)" ]
}

@test "deep-merge-by-key: per-server config merges, overlay wins keys" {
    actual=$(jq -n --slurpfile a "$FIXTURES/deep-merge-by-key-base.json" \
                   --slurpfile b "$FIXTURES/deep-merge-by-key-overlay.json" \
                   "include \"strategies\" {search: \"$MOD_DIR/lib\"}; deep_merge_by_key(\$a[0]; \$b[0])")
    expected=$(cat "$FIXTURES/deep-merge-by-key-expected.json")
    [ "$(echo "$actual" | jq -S .)" = "$(echo "$expected" | jq -S .)" ]
}

@test "replace-by:command: overlay hook replaces same-command entry" {
    actual=$(jq -n --slurpfile a "$FIXTURES/replace-by-command-base.json" \
                   --slurpfile b "$FIXTURES/replace-by-command-overlay.json" \
                   "include \"strategies\" {search: \"$MOD_DIR/lib\"}; replace_by_command(\$a[0]; \$b[0])")
    expected=$(cat "$FIXTURES/replace-by-command-expected.json")
    [ "$(echo "$actual" | jq -S .)" = "$(echo "$expected" | jq -S .)" ]
}

@test "replace-by:matcher+command: identity by matcher AND command" {
    actual=$(jq -n --slurpfile a "$FIXTURES/replace-by-matcher-command-base.json" \
                   --slurpfile b "$FIXTURES/replace-by-matcher-command-overlay.json" \
                   "include \"strategies\" {search: \"$MOD_DIR/lib\"}; replace_by_matcher_command(\$a[0]; \$b[0])")
    expected=$(cat "$FIXTURES/replace-by-matcher-command-expected.json")
    [ "$(echo "$actual" | jq -S .)" = "$(echo "$expected" | jq -S .)" ]
}

@test "dispatcher: applies named strategy per path, default replace otherwise" {
    actual=$(jq -n --slurpfile rules "$FIXTURES/dispatch-rules.json" \
                   --slurpfile a "$FIXTURES/dispatch-base.json" \
                   --slurpfile b "$FIXTURES/dispatch-overlay.json" \
                   "include \"strategies\" {search: \"$MOD_DIR/lib\"}; merge_with_rules(\$a[0]; \$b[0]; \$rules[0])")
    expected=$(cat "$FIXTURES/dispatch-expected.json")
    [ "$(echo "$actual" | jq -S .)" = "$(echo "$expected" | jq -S .)" ]
}
