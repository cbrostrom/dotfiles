# ZSH Performance Optimization Guide

## Common Causes of Slow Startup on macOS

### 1. **Google Cloud SDK** (Lines 118-126 in 01-environment.zsh)
**Problem:** Loading Google Cloud SDK adds ~200-500ms
```zsh
if [ -f '/opt/homebrew/share/google-cloud-sdk/path.zsh.inc' ]; then 
    . '/opt/homebrew/share/google-cloud-sdk/path.zsh.inc'
fi
if [ -f '/opt/homebrew/share/google-cloud-sdk/completion.zsh.inc' ]; then 
    . '/opt/homebrew/share/google-cloud-sdk/completion.zsh.inc'
fi
```

**Solution:** Lazy load only when needed
```zsh
# Lazy load gcloud
gcloud() {
    unfunction gcloud
    if [ -f '/opt/homebrew/share/google-cloud-sdk/path.zsh.inc' ]; then 
        . '/opt/homebrew/share/google-cloud-sdk/path.zsh.inc'
    fi
    if [ -f '/opt/homebrew/share/google-cloud-sdk/completion.zsh.inc' ]; then 
        . '/opt/homebrew/share/google-cloud-sdk/completion.zsh.inc'
    fi
    gcloud "$@"
}
```

### 2. **Homebrew shellenv** (Lines 74-80 in 01-environment.zsh)
**Problem:** `brew shellenv` can be slow (~50-100ms)
**Solution:** Cache the output

### 3. **Zoxide init** (Line 137 in 02-plugins.zsh)
**Problem:** `zoxide init zsh` adds ~50-100ms
**Solution:** Already optimized with eval, but can be cached

### 4. **Starship init** (Line 257 in 02-plugins.zsh)
**Problem:** `starship init zsh` adds ~50-100ms
**Solution:** Can be cached or lazy loaded

### 5. **FNM env** (Line 265 in 02-plugins.zsh)
**Problem:** `fnm env --use-on-cd` adds ~50-100ms
**Solution:** Can be cached

### 6. **Duplicate compinit calls** (Lines 39-44 and 187-195 in 02-plugins.zsh)
**Problem:** compinit is called twice!
**Solution:** Remove one of them

## Optimization Strategies

### Strategy 1: Lazy Loading (Recommended)
Load tools only when first used:
- Google Cloud SDK
- Rarely used commands

### Strategy 2: Caching
Cache expensive eval commands:
- `brew shellenv`
- `starship init zsh`
- `zoxide init zsh`
- `fnm env`

### Strategy 3: Deferred Loading
Use zinit's `wait` for non-critical plugins

### Strategy 4: Remove Duplicates
- Remove duplicate compinit calls
- Consolidate similar operations

## Quick Wins

### 1. Remove Duplicate compinit
**Current:** Called at lines 39-44 AND 187-195
**Fix:** Keep only one

### 2. Lazy Load Google Cloud SDK
**Impact:** Save 200-500ms if not using gcloud

### 3. Cache Homebrew shellenv
**Impact:** Save 50-100ms

### 4. Defer non-critical plugins
**Impact:** Save 100-200ms

## Testing Your Changes

1. **Benchmark before:**
   ```bash
   ./utils/benchmark-zsh.sh
   ```

2. **Profile to find bottlenecks:**
   ```bash
   ./utils/profile-zsh-startup.sh
   ```

3. **Make changes**

4. **Benchmark after:**
   ```bash
   ./utils/benchmark-zsh.sh
   ```

## Target Times

- **Excellent:** < 100ms
- **Good:** 100-300ms
- **Acceptable:** 300-500ms
- **Needs optimization:** > 500ms

## macOS-Specific Issues

### Homebrew on Apple Silicon
- Homebrew on M1/M2/M3 Macs can be slower
- Consider caching `brew shellenv` output

### Rosetta 2
- Check if any tools are running under Rosetta
- Use native ARM64 versions when possible

## Debugging Commands

```bash
# Time individual commands
time zsh -i -c exit

# Profile with zprof
zsh -i -c 'zmodload zsh/zprof; source ~/.zshrc; zprof'

# Check what's being loaded
zsh -x -i -c exit 2>&1 | less

# Measure specific operations
time eval "$(starship init zsh)"
time eval "$(zoxide init zsh)"
time eval "$(fnm env --use-on-cd)"
```
