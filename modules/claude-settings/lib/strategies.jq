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

# get_at: read a value at a dotted path. Returns null if missing.
def get_at(path_str):
    (path_str | split(".")) as $segs
    | reduce $segs[] as $seg (.; if . == null then null else .[$seg] end);

# set_at: assign value at a dotted path. Creates intermediate objects.
def set_at(path_str; value):
    (path_str | split(".")) as $segs
    | setpath($segs; value);

# apply_strategy: dispatch by name. Default for unknown name is "replace".
def apply_strategy(strategy; base_val; overlay_val):
    if   strategy == "shallow-merge"              then shallow_merge(base_val; overlay_val)
    elif strategy == "concat-dedupe"              then concat_dedupe(base_val; overlay_val)
    elif strategy == "deep-merge-by-key"          then deep_merge_by_key(base_val; overlay_val)
    elif strategy == "replace-by:command"         then replace_by_command(base_val; overlay_val)
    elif strategy == "replace-by:matcher+command" then replace_by_matcher_command(base_val; overlay_val)
    else overlay_val   # default: replace
    end;

# merge_with_rules: starts from `base * overlay` (shallow object spread,
# overlay wins). Then for each rule, recompute the value at the rule's
# path using the named strategy applied to base[path] and overlay[path].
def merge_with_rules(base; overlay; rules):
    reduce (rules | to_entries[]) as $rule
        (base * overlay;
         ($rule.key) as $path
         | ($rule.value) as $strategy
         | (base | get_at($path)) as $bv
         | (overlay | get_at($path)) as $ov
         | if $bv == null and $ov == null then .
           elif $bv == null then .
           elif $ov == null then set_at($path; $bv)
           else set_at($path; apply_strategy($strategy; $bv; $ov))
           end);
