---
name: theme-performance
description: Shopify theme performance optimization targeting Core Web Vitals and Lighthouse scores.
---

# Theme Performance

Performance optimization guide for Shopify Online Store 2.0 themes. Targets the project's Lighthouse score goals and Shopify-specific performance best practices.

## Lighthouse Targets

| Category | Target | Notes |
|----------|--------|-------|
| Performance | 80+ | LCP, CLS, TBT are key metrics |
| Accessibility | 90+ | See [accessibility skill](../../accessibility/SKILL.md) |
| Best Practices | 90+ | HTTPS, no deprecated APIs |
| SEO | 90+ | See [SEO skill](../../seo/SKILL.md) |

## Core Web Vitals

### Largest Contentful Paint (LCP) -- target < 2.5s

LCP measures how long it takes for the largest visible content element to render.

**Common LCP elements in Shopify themes:**
- Hero images
- Product featured images
- Collection banner images

**Optimization strategies:**

```liquid
{% comment %} Preload hero image for LCP {% endcomment %}
{% if section.settings.hero_image %}
  <link
    rel="preload"
    as="image"
    href="{{ section.settings.hero_image | image_url: width: 1500 }}"
    imagesrcset="
      {{ section.settings.hero_image | image_url: width: 750 }} 750w,
      {{ section.settings.hero_image | image_url: width: 1100 }} 1100w,
      {{ section.settings.hero_image | image_url: width: 1500 }} 1500w
    "
    imagesizes="100vw"
  >
{% endif %}
```

```liquid
{% comment %} Eager load above-fold images, lazy load below-fold {% endcomment %}
{% for product in collection.products limit: 12 %}
  {% if forloop.index <= 4 %}
    {% assign loading = 'eager' %}
    {% assign fetchpriority = 'high' %}
  {% else %}
    {% assign loading = 'lazy' %}
    {% assign fetchpriority = 'auto' %}
  {% endif %}

  {{
    product.featured_image
    | image_url: width: 600
    | image_tag:
      loading: loading,
      fetchpriority: fetchpriority,
      widths: '200, 400, 600',
      sizes: '(max-width: 640px) 50vw, 25vw',
      alt: product.title
  }}
{% endfor %}
```

### Cumulative Layout Shift (CLS) -- target < 0.1

CLS measures unexpected layout shifts during page load.

**Prevention strategies:**

```liquid
{% comment %} Always specify width and height on images {% endcomment %}
<img
  src="{{ image | image_url: width: 600 }}"
  width="{{ image.width }}"
  height="{{ image.height }}"
  alt="{{ image.alt | escape }}"
  loading="lazy"
>
```

```css
/* Reserve space for images with aspect ratio */
.product-image-wrapper {
  aspect-ratio: 1 / 1;
  overflow: hidden;
}

/* Prevent font swap layout shift */
@font-face {
  font-family: 'BrandFont';
  font-display: swap;
  size-adjust: 100%;
}
```

```liquid
{% comment %} Avoid dynamic content that shifts layout {% endcomment %}
{% comment %} BAD: Injecting content that pushes elements down {% endcomment %}
{% comment %} GOOD: Reserve space for dynamic content {% endcomment %}
<div class="announcement-bar min-h-10">
  {% if settings.announcement_text != blank %}
    <p>{{ settings.announcement_text }}</p>
  {% endif %}
</div>
```

### Total Blocking Time (TBT) -- target < 200ms

TBT measures how long the main thread is blocked during page load.

**Prevention strategies:**

```liquid
{% comment %} Defer non-critical JavaScript {% endcomment %}
<script src="{{ 'component.min.js' | asset_url }}" defer></script>

{% comment %} Use type="module" for modern JS (deferred by default) {% endcomment %}
{{ 'index.min.js' | asset_url | script_tag: type: 'module' }}
```

```typescript
// Break up long tasks with requestIdleCallback
function processLargeDataset(items: Item[]): void {
  const CHUNK_SIZE = 50;
  let index = 0;

  function processChunk(): void {
    const end = Math.min(index + CHUNK_SIZE, items.length);
    for (; index < end; index++) {
      processItem(items[index]);
    }

    if (index < items.length) {
      requestIdleCallback(processChunk);
    }
  }

  requestIdleCallback(processChunk);
}
```

## Image Optimization

### Shopify CDN image filters

Always use Shopify's CDN image transformation filters instead of serving original images:

```liquid
{% comment %} Basic resize {% endcomment %}
{{ image | image_url: width: 800 }}

{% comment %} With format hint (Shopify auto-serves WebP/AVIF when supported) {% endcomment %}
{{ image | image_url: width: 800, format: 'pjpg' }}

{% comment %} Full responsive image tag {% endcomment %}
{{
  image
  | image_url: width: 1200
  | image_tag:
    loading: 'lazy',
    widths: '300, 600, 900, 1200',
    sizes: '(max-width: 640px) 100vw, (max-width: 1024px) 50vw, 33vw',
    alt: image.alt
}}
```

### Image sizing guidelines

| Context | Max Width | Sizes Attribute |
|---------|-----------|-----------------|
| Hero/banner | 1920px | `100vw` |
| Product grid (4-col) | 600px | `(max-width: 640px) 50vw, 25vw` |
| Product grid (3-col) | 800px | `(max-width: 640px) 100vw, 33vw` |
| Product detail | 1200px | `(max-width: 1024px) 100vw, 50vw` |
| Thumbnail | 200px | `100px` |
| Logo | 400px | `200px` |

## JavaScript Performance

### Module loading strategy

```typescript
// Entrypoint: Only import what's needed at startup
import { initializeBase } from '@shared/scripts/entrypoints/base';

// Store-specific modules are loaded by initializeBase
// which only initializes modules whose DOM targets exist on the page
const storeModules = {
  'my-module': MyModule,
};
```

### Lazy initialization

The `initializeBase` function only initializes modules when their corresponding DOM elements are present. This provides automatic code splitting by page:

```typescript
// Module is only initialized when data-module="product-form" exists in DOM
export class ProductForm {
  constructor(element: HTMLElement) {
    // Only runs on pages with this element
  }
}
```

### Event delegation

Use event delegation instead of attaching listeners to many elements:

```typescript
// BAD: Listener on every button
document.querySelectorAll('.add-to-cart').forEach((btn) => {
  btn.addEventListener('click', handleAddToCart);
});

// GOOD: Single delegated listener
document.addEventListener('click', (e) => {
  const target = (e.target as HTMLElement).closest('[data-add-to-cart]');
  if (target) handleAddToCart(e, target);
});
```

## CSS Performance

### Tailwind v4 with @tailwindcss/vite

The project uses `@tailwindcss/vite` which handles:
- Automatic detection of utility usage in templates
- Tree-shaking of unused utilities
- Minification in production builds

### Critical CSS considerations

```liquid
{% comment %} Inline critical styles for above-fold content if needed {% endcomment %}
{% comment %} But prefer Vite's built CSS -- Shopify CDN caches aggressively {% endcomment %}

{% comment %} Load main stylesheet {% endcomment %}
{{ 'index.min.css' | asset_url | stylesheet_tag }}
```

### Reduce custom CSS

```css
/* BAD: Custom CSS when Tailwind utility exists */
.my-flex-container {
  display: flex;
  align-items: center;
  gap: 1rem;
}

/* GOOD: Use Tailwind classes in markup */
/* <div class="flex items-center gap-4"> */
```

## Liquid Performance

### Minimize Liquid rendering cost

```liquid
{% comment %} BAD: Accessing settings/objects repeatedly in loops {% endcomment %}
{% for product in collection.products %}
  {% if settings.show_vendor %}
    {{ product.vendor }}
  {% endif %}
{% endfor %}

{% comment %} GOOD: Assign outside the loop {% endcomment %}
{% assign show_vendor = settings.show_vendor %}
{% for product in collection.products %}
  {% if show_vendor %}
    {{ product.vendor }}
  {% endif %}
{% endfor %}
```

### Avoid unnecessary section rendering

```liquid
{% comment %} BAD: Rendering a complex section unconditionally {% endcomment %}
{% render 'complex-recommendations' %}

{% comment %} GOOD: Only render when needed {% endcomment %}
{% if section.settings.show_recommendations %}
  {% render 'complex-recommendations', product: product %}
{% endif %}
```

### Efficient collection filtering

```liquid
{% comment %} BAD: Filtering in Liquid (slow for large collections) {% endcomment %}
{% for product in collection.products %}
  {% if product.tags contains 'featured' %}
    {% render 'product-card', product: product %}
  {% endif %}
{% endfor %}

{% comment %} GOOD: Use Shopify's collection filtering or curated collections {% endcomment %}
{% for product in collections.featured.products limit: 8 %}
  {% render 'product-card', product: product %}
{% endfor %}
```

## Font Performance

### Font loading strategy

```liquid
{% comment %} Preload critical fonts {% endcomment %}
<link
  rel="preload"
  as="font"
  type="font/woff2"
  href="{{ 'brand-font.woff2' | asset_url }}"
  crossorigin
>
```

```css
/* Use font-display: swap for custom fonts */
@font-face {
  font-family: 'BrandFont';
  src: url('brand-font.woff2') format('woff2');
  font-weight: 400;
  font-style: normal;
  font-display: swap;
}
```

### System font fallbacks

Define font stacks with system font fallbacks to minimize CLS from font swapping:

```css
@theme {
  --font-heading: 'BrandFont', system-ui, -apple-system, sans-serif;
  --font-body: 'BrandBodyFont', Georgia, serif;
}
```

## Performance Monitoring

### Shopify-specific tools

| Tool | Access | Measures |
|------|--------|----------|
| Shopify Speed Score | Shopify admin → Online Store → Themes | Aggregate Lighthouse score |
| Google PageSpeed Insights | web | Core Web Vitals + Lighthouse |
| Chrome DevTools Performance tab | local | Runtime performance profiling |
| Chrome DevTools Lighthouse tab | local | Full audit with recommendations |
| WebPageTest | web | Detailed waterfall analysis |

### Pre-PR performance check

Before submitting a PR, verify:
- [ ] No new render-blocking resources added
- [ ] Images use Shopify CDN filters with appropriate widths
- [ ] Below-fold images have `loading="lazy"`
- [ ] Above-fold images have `loading="eager"` and `fetchpriority="high"`
- [ ] New JavaScript is deferred or loaded as module
- [ ] No inline styles where Tailwind utilities exist
- [ ] Liquid loops are limited or paginated
- [ ] Width and height specified on all images
