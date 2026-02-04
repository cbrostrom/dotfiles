# Phi Settings Guide

## 📁 Filstruktur

```
/Users/Christian.Brostrom/Documents/Vivaldi/phi/
├── custom.css           # Hovedtema-fil (modificer ikke direkte)
├── custom.css.backup    # Backup af original
├── phi-settings.css     # DIN customization fil (rediger denne!)
└── CHANGELOG.md         # Liste over ændringer
```

## 🎯 Sådan virker det

1. **custom.css** definerer defaults i `:root` blokken
2. **custom.css** importerer derefter `phi-settings.css` med `@import`
3. **phi-settings.css** bruger `body` selector som har HØJERE specificity end `:root`
4. Derfor overskriver phi-settings.css defaults
5. Når du opdaterer custom.css, bevares dine settings i phi-settings.css

## ✏️ Sådan redigerer du settings

Åbn `phi-settings.css` og ændr værdier efter behov:

```css
body {
    /* Eksempel: Gør tabs endnu højere */
    --phi--tab-height: 50;
    
    /* Eksempel: Mere padding i tabs */
    --phi--tab-padding: 16;
    
    /* Eksempel: Mindre pinned tabs */
    --phi--pinned-tab-max-height: 60;
}
```

## 🔄 Sådan ser du ændringer

1. Gem `phi-settings.css`
2. I Vivaldi: Gå til Tools → Developer Tools → Experiments
3. Genindlæs CSS eller genstart Vivaldi

## 🎨 Vigtige variabler

### Tab-indstillinger
- `--phi--tab-height: 40` - Højde på normale tabs (px)
- `--phi--tab-spacing: 8` - Afstand mellem tabs (px)
- `--phi--tab-padding: 12` - Indvendig padding i tabs (px)
- `--phi--pinned-tab-max-height: 70` - Max højde på pinned tabs (px)
- `--phi--pinned-tab-aspect-ratio: 0.9` - Bredde/højde ratio for pinned tabs

### Sidebar
- `--phi--sidebar-width: 340` - Bredde af sidebar (px)
- `--phi--compact-sidebar-width: 50` - Bredde i compact mode (px)
- `--phi--pinned-column-count: 4` - Antal kolonner for pinned tabs

### Animationer
- `--phi--transition-speed: 0.2s` - Hastighed af animationer

### Webview styling
- `--phi--webview-border-radius: 8` - Runde hjørner på webview (px)
- `--phi--webview-shadow-size: 12` - Skygge størrelse (px)

## 🐛 Troubleshooting

### Ændringer virker ikke?
1. Tjek at `phi-settings.css` ligger i `phi/` mappen
2. Tjek at filen bruger `body` selector (IKKE `:root`)
3. Genindlæs Vivaldi
4. Tjek for syntaksfejl i CSS

### Vil tilbage til defaults?
Fjern eller kommenter linjer i `phi-settings.css`:

```css
body {
    /* --phi--tab-height: 50;  <-- Kommenteret ud, bruger default */
    --phi--tab-padding: 16;    /* <-- Aktiv, overskriver default */
}
```

### Vil starte forfra?
1. Slet `phi-settings.css`
2. Kopier settings fra `custom.css` `:root` blok
3. Gem som ny `phi-settings.css`

## 💡 Tips

- Start med små ændringer og test én ad gangen
- Brug hele tal for px-værdier (ikke decimaler)
- Gem ofte og genindlæs for at se ændringer
- Hold en backup af din phi-settings.css

## 📞 Behov for hjælp?

Se `CHANGELOG.md` for detaljer om alle tilgængelige variabler og deres effekt.
