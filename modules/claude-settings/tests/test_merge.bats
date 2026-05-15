#!/usr/bin/env bats

setup() {
    DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
    MOD_DIR="$DOTFILES_DIR/modules/claude-settings"
    FIXTURES="$MOD_DIR/tests/fixtures/e2e"
    TMPDIR=$(mktemp -d)
    cp "$FIXTURES"/{base,darwin,linux,override,rules}.json "$TMPDIR"/
    mv "$TMPDIR/rules.json" "$TMPDIR/_merge-config.json"
    mv "$TMPDIR/base.json" "$TMPDIR/settings.base.json"
    mv "$TMPDIR/darwin.json" "$TMPDIR/settings.darwin.json"
    mv "$TMPDIR/linux.json" "$TMPDIR/settings.linux.json"
    mv "$TMPDIR/override.json" "$TMPDIR/settings.override.json"
}

teardown() { rm -rf "$TMPDIR"; }

@test "merge: darwin platform produces expected merged output" {
    CLAUDE_DIR="$TMPDIR" PLATFORM=darwin "$MOD_DIR/merge.sh"
    diff <(jq -S . "$TMPDIR/settings.local.json") \
         <(jq -S . "$FIXTURES/expected-darwin.json")
}

@test "merge: linux platform produces expected merged output" {
    CLAUDE_DIR="$TMPDIR" PLATFORM=linux "$MOD_DIR/merge.sh"
    diff <(jq -S . "$TMPDIR/settings.local.json") \
         <(jq -S . "$FIXTURES/expected-linux.json")
}

@test "merge: idempotent — second run produces byte-identical output" {
    CLAUDE_DIR="$TMPDIR" PLATFORM=darwin "$MOD_DIR/merge.sh"
    sha1=$(sha256sum "$TMPDIR/settings.local.json" 2>/dev/null || shasum -a 256 "$TMPDIR/settings.local.json")
    CLAUDE_DIR="$TMPDIR" PLATFORM=darwin "$MOD_DIR/merge.sh"
    sha2=$(sha256sum "$TMPDIR/settings.local.json" 2>/dev/null || shasum -a 256 "$TMPDIR/settings.local.json")
    [ "$sha1" = "$sha2" ]
}

@test "merge: missing override.json is treated as {}" {
    rm "$TMPDIR/settings.override.json"
    CLAUDE_DIR="$TMPDIR" PLATFORM=darwin "$MOD_DIR/merge.sh"
    jq empty "$TMPDIR/settings.local.json"
}

@test "merge: invalid JSON in base aborts without touching settings.local.json" {
    echo "not json" > "$TMPDIR/settings.base.json"
    echo '{"sentinel":true}' > "$TMPDIR/settings.local.json"
    run env CLAUDE_DIR="$TMPDIR" PLATFORM=darwin "$MOD_DIR/merge.sh"
    [ "$status" -ne 0 ]
    [ "$(jq -r .sentinel "$TMPDIR/settings.local.json")" = "true" ]
}
