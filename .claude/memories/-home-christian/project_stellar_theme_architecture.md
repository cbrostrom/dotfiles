---
name: Stellar Shopify — Theme Patch Architecture Plan
description: Analyse og plan for at erstatte fork-and-diverge med patch/inheritance model i stellar-shopify
type: project
originSessionId: 6edb1b5d-97e2-4bb6-83bc-4edef4ab61e8
---
Stellar-shopify bruger i dag fork-and-diverge: hvert brand (wedgwood, iittala, georg-jensen, waterford, royal-copenhagen, royal-doulton, moominarabia) har sin egen fuld kopi af theme.

**Why:** Brands har forskellige design-krav, men fork-modellen giver usynlig divergens og manuel bugfix-propagering.

**How to apply:** Næste trin er at implementere patch-modellen beskrevet nedenfor.

## Nuværende tilstand (målt)

- 8 stores, 1834 filer, ~548K ord
- 55 sections tracket på tværs:
  - 3 identiske (100% ens)
  - 41 delvist divergerede
  - 11 fuldt divergerede (brand-unikke)
- Mest divergerede: `shopping-cart` (40%), `predictive-search` (55%), `media-banner` (57%)
- Mest stabile (burde aldrig have været kopieret): `divider`, `page-blog`, `page-addresses` (100%)

## Valgt løsning: Patch / Inheritance Model

`stores/base/theme/` er eneste kilde til sandhed for shared sections.  
`stores/{store}/theme/` er det komplette, materialiserede theme (redigérbart, theme-check peger hertil).  
`.overrides` manifest i hvert store angiver hvilke filer der er brand-ejede.

### Mappestruktur

```
stores/
  base/theme/          ← source of truth — rediger her for shared changes
  wedgwood/theme/      ← komplet arbejdende theme (theme-check root)
    sections/
      header.liquid    ← enten base-kopi ELLER wedgwood-override
    .overrides         ← liste over store-ejede filer
```

### `.overrides` format

```
# stores/wedgwood/theme/.overrides
sections/header.liquid
sections/media-banner.liquid
sections/footer.liquid
```

### Build MERGE fase (tilføjes til `build/core/orchestrator.ts`)

Ny fase 0 før eksisterende faser (BARREL → JSON → SCHEMA → LOCALE → VITE):

```typescript
async function mergeBaseIntoStore(store: string) {
  const overrides = readOverridesManifest(`stores/${store}/theme/.overrides`);
  
  for (const file of walkDir('stores/base/theme')) {
    const storeFile = `stores/${store}/theme/${file}`;
    
    if (overrides.has(file)) continue;        // store-ejet → rør ikke
    
    await fs.copy(`stores/base/theme/${file}`, storeFile, { overwrite: true });
  }
}
```

### Developer workflow

```bash
# Shared fix (fx bugfix i cart-drawer):
# Rediger stores/base/theme/sections/cart-drawer.liquid
# Næste build kopierer til ALLE stores automatisk

# Brand-specifik ændring:
npm run override:add wedgwood sections/header.liquid
# → tilføjer til .overrides, MERGE springer den over fremover
# → rediger stores/wedgwood/theme/sections/header.liquid normalt

# theme-check — altid på komplet materialiseret theme:
shopify theme check stores/wedgwood/theme/
```

### theme-check konfiguration

theme-check har ingen support for multiple root paths — kan kun pege på én komplet theme-mappe.  
Løsning: udviklere redigerer altid i `stores/{store}/theme/` (komplet), aldrig i isoleret overrides-mappe.

```yaml
# stores/wedgwood/theme/.theme-check.yml
extends: ../../../../.theme-check.yml
root: .
```

```json
// .vscode/settings.json
{ "shopifyLiquid.rootUri": "stores/wedgwood/theme" }
```

## Migrationsstrategi (tre trin)

**Trin 1 — ingen risiko:** Slet 100%-identiske filer fra alle store-mapper (divider, page-blog, page-addresses etc.) — byg validerer at de hentes fra base.

**Trin 2 — lav risiko:** Sections 95-99% ens → tjek diff, send tilbage til base eller bekræft som override.

**Trin 3 — kræver brand-dialog:** Sections 40-78% ens (header, cart, media-banner, footer) → afklar med hvert brand-team om forskelle er intentionelle krav eller drift. Intentionel → `override:add`. Drift → merge til base.

## Hvad mangler at bygges

- [ ] MERGE fase i `build/core/orchestrator.ts`
- [ ] `npm run override:add <store> <filepath>` script
- [ ] Per-store `.theme-check.yml` der peger på sin egen `theme/` mappe
- [ ] VS Code multi-root workspace config (en entry per store)
- [ ] Migration: gennemgang af de 41 delvist-divergerede sections
