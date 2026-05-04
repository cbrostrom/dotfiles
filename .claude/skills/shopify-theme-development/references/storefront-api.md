---
name: storefront-api
description: Client-side Shopify API patterns for cart, search, sections, and product recommendations.
---

# Storefront API Patterns

Client-side JavaScript patterns for interacting with Shopify's theme APIs. These are the AJAX endpoints available in Online Store themes (not the Storefront GraphQL API).

## Cart API

### Fetch current cart

```typescript
interface ShopifyCart {
  token: string;
  note: string | null;
  attributes: Record<string, string>;
  total_price: number;
  total_discount: number;
  total_weight: number;
  item_count: number;
  items: ShopifyCartItem[];
  currency: string;
}

async function getCart(): Promise<ShopifyCart> {
  const response = await fetch('/cart.js');
  if (!response.ok) throw new Error(`Cart fetch failed: ${response.status}`);
  return response.json();
}
```

### Add to cart

```typescript
interface AddToCartPayload {
  id: number;
  quantity: number;
  properties?: Record<string, string>;
  selling_plan?: number;
}

async function addToCart(items: AddToCartPayload[]): Promise<ShopifyCart> {
  const response = await fetch('/cart/add.js', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ items }),
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.description || 'Failed to add to cart');
  }

  return response.json();
}
```

### Update cart item quantity

```typescript
async function updateCartItem(key: string, quantity: number): Promise<ShopifyCart> {
  const response = await fetch('/cart/change.js', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ id: key, quantity }),
  });

  if (!response.ok) throw new Error('Failed to update cart');
  return response.json();
}
```

### Bulk update cart

```typescript
async function updateCart(updates: Record<string, number>): Promise<ShopifyCart> {
  const response = await fetch('/cart/update.js', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ updates }),
  });

  if (!response.ok) throw new Error('Failed to update cart');
  return response.json();
}
```

### Clear cart

```typescript
async function clearCart(): Promise<ShopifyCart> {
  const response = await fetch('/cart/clear.js', { method: 'POST' });
  if (!response.ok) throw new Error('Failed to clear cart');
  return response.json();
}
```

### Update cart note and attributes

```typescript
async function updateCartNote(note: string): Promise<ShopifyCart> {
  const response = await fetch('/cart/update.js', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ note }),
  });
  return response.json();
}

async function updateCartAttributes(attributes: Record<string, string>): Promise<ShopifyCart> {
  const response = await fetch('/cart/update.js', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ attributes }),
  });
  return response.json();
}
```

## Section Rendering API

Re-render one or more sections without a full page reload. Essential for dynamic cart drawers, product forms, and filtered collections.

### Single section

```typescript
async function renderSection(sectionId: string, url?: string): Promise<string> {
  const targetUrl = url || window.location.pathname;
  const response = await fetch(`${targetUrl}?sections=${sectionId}`);

  if (!response.ok) throw new Error(`Section render failed: ${response.status}`);

  const data = await response.json();
  return data[sectionId];
}
```

### Multiple sections

```typescript
async function renderSections(sectionIds: string[], url?: string): Promise<Record<string, string>> {
  const targetUrl = url || window.location.pathname;
  const sectionsParam = sectionIds.join(',');
  const response = await fetch(`${targetUrl}?sections=${sectionsParam}`);

  if (!response.ok) throw new Error(`Sections render failed: ${response.status}`);
  return response.json();
}
```

### Replacing section content and re-initializing

After replacing section HTML, dispatch `DOM:updated` so that JavaScript modules re-initialize on the new DOM:

```typescript
async function refreshSection(sectionId: string): Promise<void> {
  const html = await renderSection(sectionId);
  const container = document.getElementById(`shopify-section-${sectionId}`);

  if (!container) return;

  container.innerHTML = html;

  window.dispatchEvent(
    new CustomEvent('DOM:updated', {
      detail: { container },
    }),
  );
}
```

### Section rendering after cart update

Common pattern: update cart then refresh cart-related sections:

```typescript
async function addToCartAndRefresh(variantId: number, quantity: number): Promise<void> {
  await addToCart([{ id: variantId, quantity }]);

  const sections = await renderSections([
    'cart-drawer',
    'cart-icon-bubble',
  ]);

  for (const [id, html] of Object.entries(sections)) {
    const el = document.getElementById(`shopify-section-${id}`);
    if (el) {
      el.innerHTML = html;
      window.dispatchEvent(new CustomEvent('DOM:updated', { detail: { container: el } }));
    }
  }
}
```

## Predictive Search API

### Basic search

```typescript
interface PredictiveSearchResult {
  resources: {
    results: {
      products: ShopifyProduct[];
      collections: ShopifyCollection[];
      pages: ShopifyPage[];
      articles: ShopifyArticle[];
      queries: { text: string; url: string }[];
    };
  };
}

async function predictiveSearch(query: string, types = 'product,collection,page'): Promise<PredictiveSearchResult> {
  const params = new URLSearchParams({
    q: query,
    'resources[type]': types,
    'resources[limit]': '4',
  });

  const response = await fetch(`/search/suggest.json?${params}`);
  if (!response.ok) throw new Error('Search failed');
  return response.json();
}
```

### With debouncing

```typescript
import { debounce } from '@shared/scripts/utils/debounce';

const debouncedSearch = debounce(async (query: string) => {
  if (query.length < 2) return;

  const results = await predictiveSearch(query);
  renderSearchResults(results);
}, 300);

searchInput.addEventListener('input', (e) => {
  const target = e.target as HTMLInputElement;
  debouncedSearch(target.value);
});
```

## Product Recommendations

```typescript
async function getProductRecommendations(
  productId: number,
  limit = 4,
  intent: 'related' | 'complementary' = 'related',
): Promise<string> {
  const params = new URLSearchParams({
    product_id: String(productId),
    limit: String(limit),
    intent,
    section_id: 'product-recommendations',
  });

  const response = await fetch(`/recommendations/products?${params}`);
  if (!response.ok) throw new Error('Recommendations failed');
  return response.text();
}
```

## Error Handling Patterns

### Cart error handling

Shopify returns specific error codes for cart operations:

```typescript
interface ShopifyCartError {
  status: number;
  message: string;
  description: string;
}

async function safeAddToCart(variantId: number, quantity: number): Promise<ShopifyCart | null> {
  try {
    return await addToCart([{ id: variantId, quantity }]);
  } catch (error) {
    if (error instanceof Error) {
      // Common errors:
      // - "Cannot find variant" (invalid variant ID)
      // - "Cart Error" with description about inventory
      console.error('Cart error:', error.message);
    }
    return null;
  }
}
```

### Rate limiting

Shopify may rate-limit AJAX requests. Implement request queuing for rapid operations:

```typescript
class CartQueue {
  private queue: Array<() => Promise<void>> = [];
  private processing = false;

  async add(operation: () => Promise<void>): Promise<void> {
    return new Promise((resolve, reject) => {
      this.queue.push(async () => {
        try {
          await operation();
          resolve();
        } catch (e) {
          reject(e);
        }
      });
      this.process();
    });
  }

  private async process(): Promise<void> {
    if (this.processing) return;
    this.processing = true;

    while (this.queue.length > 0) {
      const operation = this.queue.shift();
      if (operation) await operation();
    }

    this.processing = false;
  }
}
```

## Important Notes

- All AJAX endpoints return JSON (append `.js` to the URL)
- Cart operations should update the UI via Section Rendering API, not by manipulating DOM directly
- Always dispatch `DOM:updated` after replacing section HTML so modules re-initialize
- Use `debounce` from `@shared/scripts/utils/debounce` for search and other rapid-fire inputs
- Handle errors gracefully -- show user-friendly messages, not technical errors
