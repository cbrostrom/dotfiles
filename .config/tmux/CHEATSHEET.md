# tmux cheatsheet — laesr setup

> **Prefix = `Ctrl+a`** (alt det nedenfor med "prefix" betyder først `Ctrl+a`, så bogstavet)
>
> Når du ser `prefix + r` betyder det: hold Ctrl, tryk a, slip begge, tryk r.

---

## UGE 1 — Lær KUN disse 12 kommandoer

Det er nok til at du kan bruge tmux produktivt. Resten kommer naturligt.

### Start / stop

| Kommando | Hvad det gør |
|---|---|
| `tmux` | Start ny session |
| `tmux new -s arbejde` | Start session med navn "arbejde" |
| `tmux a` | Re-attach til sidste session |
| `tmux a -t arbejde` | Attach til specifik session |
| `tmux ls` | List alle kørende sessions |
| `prefix + d` | **Detach** (forlad session, den kører videre i baggrunden) |

### Splits & windows (det du bruger 90% af tiden)

| Keybind | Handling |
|---|---|
| `prefix + v` | Split **lodret** (panes side om side) |
| `prefix + h` | Split **vandret** (panes oven over hinanden) |
| `prefix + c` | Ny window (faneblad) |
| `prefix + n` / `prefix + p` | Næste / forrige window |
| `prefix + 1`–`9` | Hop til window nr. 1–9 |
| `Alt + pile` | Skift mellem panes (intet prefix nødvendigt!) |

---

## UGE 2 — Når du er fortrolig med ovenstående

### Sessions (vigtig superpower)

| Keybind | Handling |
|---|---|
| `prefix + O` | **Sessionx fuzzy-switcher** — søg/skift session, window, eller pane |
| `prefix + s` | Built-in session list (simpel) |
| `prefix + $` | Omdøb nuværende session |
| `prefix + ,` | Omdøb nuværende window |

### Pane-magi

| Keybind | Handling |
|---|---|
| `prefix + z` | **Zoom pane** (toggler — fuldskærm pane / tilbage) |
| `prefix + x` | Luk pane (med bekræftelse) |
| `prefix + {` / `prefix + }` | Flyt pane venstre / højre |
| `prefix + space` | Cykl gennem layouts |

### Layouts (hurtige presets)

| Keybind | Handling |
|---|---|
| `prefix + l` | Main vertical (én stor pane + mindre til siden) |
| `prefix + V` | Even vertical (alle lige store, lodret stak) |
| `prefix + H` | Even horizontal (alle lige store, vandret) |

### Copy mode (læs scrollback / kopier tekst)

| Keybind | Handling |
|---|---|
| `prefix + [` | Gå ind i copy mode (Vim-style navigation) |
| `q` | Forlad copy mode |
| `space` | Start markering |
| `enter` | Kopier markering (lander i macOS clipboard via tmux-yank) |
| `prefix + ]` | Paste det sidst kopierede |

### Plugins (TPM)

| Keybind | Handling |
|---|---|
| `prefix + I` | Install plugins (capital i) — kør efter ny plugin tilføjes |
| `prefix + U` | Update plugins |
| `prefix + alt + u` | Uninstall plugins som er fjernet fra config |

### Plugin-shortcuts

| Keybind | Plugin | Handling |
|---|---|---|
| `prefix + u` | tmux-fzf-url | Fuzzy-vælg URL fra scrollback, åbner i browser |
| `prefix + o` | tmux-open | Åben fil/URL under cursor |
| `prefix + Ctrl-s` | tmux-resurrect | Manuel save af session |
| `prefix + Ctrl-r` | tmux-resurrect | Manuel restore |

---

## Avanceret (når du er klar)

### Konfig

| Kommando | Handling |
|---|---|
| `prefix + r` | Reload config (efter ændringer i `~/dotfiles/.config/tmux/tmux.conf`) |

### Mouse er ON

- Scroll-hjul i terminal → scrollback
- Klik på pane → fokus
- Drag på pane-border → resize
- Højreklik på status bar → context menu
- Højreklik på pane → context menu

### Persistence (du behøver ikke gøre noget)

- **Continuum** auto-saver hver 15 min
- Når du starter tmux igen → sessions/windows/panes restoreres automatisk
- Mister du strøm? Bare `tmux a` — alt er tilbage

---

## Min anbefalede daglige workflow

```bash
# Morgen: start session for dagens arbejde
tmux new -s laesr

# I tmux:
# - prefix + v → split for editor + terminal
# - prefix + c → window for git
# - prefix + c → window for tests/server

# Slut på dagen: lad være med at lukke. Bare:
# prefix + d   (detach — session kører videre)

# Næste morgen:
tmux a
# Alt er præcis som du forlod det.
```

---

## Troubleshooting

**Plugins virker ikke?**
→ `prefix + I` (capital i). Hvis ikke: `~/.tmux/plugins/tpm/bin/install_plugins`

**Farver er forkerte i nvim?**
→ Tjek at Ghostty sender `xterm-ghostty` eller `xterm-256color`: `echo $TERM` (uden for tmux)

**Continuum genskaber ikke sessions?**
→ Tjek at saves findes: `ls ~/.tmux/resurrect/`

**Sessionx (`prefix + O`) virker ikke?**
→ Kræver `fzf` og `lsd`: `brew install fzf lsd`

**Ændring i config virker ikke?**
→ `prefix + r` for reload. Hvis stadig ikke: kill alle sessions (`tmux kill-server`) og start igen.

---

## Hvad er IKKE sat op (bevidst)

- `cmatrix` lock screen → fjernet, brug standard
- `tmux-spotify` → fjernet, brug Spotify-app
- Continuum auto-boot ved Mac-start → off, du styrer selv hvornår tmux starter
- `remain-on-exit` → off, døde panes lukker automatisk

Vil have noget af det tilbage? Sig til.
