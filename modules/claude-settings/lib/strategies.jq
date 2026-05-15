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
