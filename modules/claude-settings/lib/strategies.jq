# Strategy library — one filter per merge strategy.

# shallow_merge: per-key overlay wins. Used for {key: bool|scalar} maps
# like enabledPlugins.
def shallow_merge(base; overlay):
    base + overlay;

# concat_dedupe: array append with order preserved, duplicates removed
# keeping first occurrence. Used for permissions.allow/ask/deny arrays.
def concat_dedupe(base; overlay):
    reduce (base + overlay)[] as $item ([]; if (. | index([$item])) then . else . + [$item] end);

# deep_merge_by_key: object overlay. For each key in overlay:
#   - if base has same key and both values are objects → recurse with `*`
#   - else overlay value wins.
# Used for mcpServers, extraKnownMarketplaces.
def deep_merge_by_key(base; overlay):
    base as $b | overlay as $o
    | reduce ($o | keys_unsorted[]) as $k
        ($b;
         if (.[$k] | type) == "object" and ($o[$k] | type) == "object"
         then .[$k] = (.[$k] * $o[$k])
         else .[$k] = $o[$k]
         end);

# Helper: top-level entry has a "hooks" array of command objects.
# Identity = the command path inside the first hook (Claude Code's hook shape).
def _hook_id_command(entry): entry.hooks[0].command;

# replace_by_command: take entries from base whose hook command does NOT
# appear in overlay; then append all overlay entries. Overlay wins on
# collision; new ones added at end.
def replace_by_command(base; overlay):
    (overlay | map(_hook_id_command(.))) as $owned
    | (base | map(select(_hook_id_command(.) as $id | $owned | index([$id]) | not)))
      + overlay;

# _merge_inner_hooks: concat-dedupe by command, keep first occurrence.
def _merge_inner_hooks(a; b):
    reduce (a + b)[] as $h ([];
        if any(.[]; .command == $h.command) then . else . + [$h] end);

# replace_by_matcher_command: outer entries identified by matcher.
# Same matcher → merge inner hooks by command. New matcher → append.
def replace_by_matcher_command(base; overlay):
    (base | map(.matcher)) as $base_matchers
    | (base
       | map(. as $b
             | (overlay | map(select(.matcher == $b.matcher))) as $o
             | if ($o | length) > 0
               then $b | .hooks = _merge_inner_hooks($b.hooks; $o[0].hooks)
               else $b
               end))
      + (overlay | map(select(.matcher as $m | $base_matchers | index([$m]) | not)));
