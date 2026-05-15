# Strategy library — one filter per merge strategy.

# shallow_merge: per-key overlay wins. Used for {key: bool|scalar} maps
# like enabledPlugins.
def shallow_merge(base; overlay):
    base + overlay;

# concat_dedupe: array append with order preserved, duplicates removed
# keeping first occurrence. Used for permissions.allow/ask/deny arrays.
def concat_dedupe(base; overlay):
    reduce (base + overlay)[] as $item ([]; if (. | index([$item])) then . else . + [$item] end);
