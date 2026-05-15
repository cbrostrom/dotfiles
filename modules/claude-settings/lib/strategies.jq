# Strategy library — one filter per merge strategy.

# shallow_merge: per-key overlay wins. Used for {key: bool|scalar} maps
# like enabledPlugins.
def shallow_merge(base; overlay):
    base + overlay;
