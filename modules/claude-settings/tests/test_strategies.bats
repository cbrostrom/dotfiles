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
