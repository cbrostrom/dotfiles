# Performance Fixes for macOS Startup Delay

## Hvad er blevet fikset?

Jeg har implementeret flere optimeringer for at reducere startup-tiden på din Mac:

### 1. **Google Cloud SDK Lazy Loading** ⚡
**Problem:** Google Cloud SDK loader ved hver shell-start (~200-500ms)
**Fix:** SDK loades nu kun når du bruger `gcloud` kommandoen første gang

### 2. **Homebrew shellenv Caching** 💾
**Problem:** `brew shellenv` køres ved hver start (~50-100ms)
**Fix:** Output caches i 24 timer og genbruges

### 3. **Init Command Caching** 🚀
**Problem:** `starship init`, `zoxide init`, `fnm env` køres hver gang (~150-300ms samlet)
**Fix:** Output caches i 24 timer for hurtigere load

### 4. **Duplicate compinit Removed** 🔧
**Problem:** `compinit` blev kaldt to gange
**Fix:** Fjernet duplikatet

### 5. **Performance Module** 📊
**Ny fil:** `00-performance.zsh` loader før alt andet og sætter caching op

## Forventet forbedring

**Før:** ~1-2 sekunder
**Efter:** ~200-500ms (50-75% hurtigere)

## Test din forbedring

### 1. Benchmark (på din Mac)
```bash
cd ~/.config/dotfiles
chmod +x utils/benchmark-zsh.sh
./utils/benchmark-zsh.sh
```

### 2. Detaljeret profiling
```bash
chmod +x utils/profile-zsh-startup.sh
./utils/profile-zsh-startup.sh
```

### 3. Manuel test
```bash
# Test 10 gange og se gennemsnittet
for i in {1..10}; do time zsh -i -c exit; done
```

## Hvad sker der nu?

### Cache-filer oprettes her:
```
~/.cache/zsh/
├── brew-shellenv.zsh    # Homebrew environment (opdateres hver 24h)
└── init/
    ├── starship.zsh     # Starship prompt init (opdateres hver 24h)
    ├── zoxide.zsh       # Zoxide init (opdateres hver 24h)
    └── fnm.zsh          # FNM init (opdateres hver 24h)
```

### Lazy loading:
- **Google Cloud SDK:** Loades kun når du kører `gcloud` første gang
- **Alle andre tools:** Loades normalt, men bruger cached output

## Ryd cache hvis noget går galt

Hvis du oplever problemer, kan du nemt rydde cachen:

```bash
# Ryd alt cache
rm -rf ~/.cache/zsh/

# Eller ryd specifik cache
rm ~/.cache/zsh/brew-shellenv.zsh
rm -rf ~/.cache/zsh/init/

# Genstart shell
exec zsh
```

Cachen regenereres automatisk næste gang.

## Yderligere optimering (valgfrit)

Hvis du stadig oplever delay, kan du:

### 1. Disable plugins du ikke bruger
Rediger `zsh/02-plugins.zsh` og kommenter plugins ud:
```zsh
# zinit wait lucid for \
#     OMZP::npm  # <-- Kommenter ud hvis du ikke bruger npm meget
```

### 2. Lazy load flere tools
Du kan lazy loade andre tools på samme måde som Google Cloud SDK.

### 3. Reducer zinit plugins
Færre plugins = hurtigere startup.

## Troubleshooting

### Cache opdateres ikke
```bash
# Force regenerer alle caches
rm -rf ~/.cache/zsh/
exec zsh
```

### Google Cloud SDK virker ikke
```bash
# Test at lazy loading virker
gcloud version

# Hvis det fejler, load manuelt:
source /opt/homebrew/share/google-cloud-sdk/path.zsh.inc
```

### Stadig langsom?
```bash
# Kør profiling for at finde bottleneck
./utils/profile-zsh-startup.sh
```

## Hvad skal du gøre nu?

1. **På din Mac:** Pull de nye ændringer
   ```bash
   cd ~/.config/dotfiles
   git pull
   ```

2. **Genstart din shell**
   ```bash
   exec zsh
   ```

3. **Test forbedringen**
   ```bash
   ./utils/benchmark-zsh.sh
   ```

4. **Nyd den hurtigere startup!** 🚀

## Bemærk

- Første gang efter opdatering vil være lidt langsommere (genererer cache)
- Efterfølgende starts vil være meget hurtigere
- Cache opdateres automatisk hver 24. time
- Ingen funktionalitet er fjernet, kun optimeret

## Spørgsmål?

Hvis du stadig oplever delay eller har spørgsmål:
1. Kør `./utils/profile-zsh-startup.sh` og send output
2. Kør `./utils/benchmark-zsh.sh` for at se gennemsnitlig tid
3. Check om der er fejl: `zsh -x -i -c exit 2>&1 | grep error`
