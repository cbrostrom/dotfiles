---
name: liquid-patterns
description: Advanced Liquid template patterns for Shopify Online Store 2.0 themes.
---

# Liquid Patterns

Advanced Liquid patterns for Shopify theme development. These patterns follow the project's conventions and complement the quick-reference in `shopify-best-practices.mdc`.

## Section and Block Rendering

### Dynamic section with blocks

```liquid
{% liquid
  assign section_padding_top = section.settings.padding_top
  assign section_padding_bottom = section.settings.padding_bottom
  assign color_scheme = section.settings.color_scheme
%}

<section
  id="section-{{ section.id }}"
  class="section-padding"
  style="--padding-top: {{ section_padding_top }}px; --padding-bottom: {{ section_padding_bottom }}px;"
  data-color-scheme="{{ color_scheme }}"
>
  <div class="container">
    {% for block in section.blocks %}
      {% case block.type %}
        {% when 'heading' %}
          {% render 'block-heading', block: block %}
        {% when 'text' %}
          {% render 'block-text', block: block %}
        {% when 'button' %}
          {% render 'block-button', block: block %}
        {% when '@app' %}
          {% render block %}
      {% endcase %}
    {% endfor %}
  </div>
</section>
```

### Block snippet with shopify_attributes

```liquid
{% comment %} snippets/block-heading.liquid {% endcomment %}
<{{ block.settings.heading_tag | default: 'h2' }}
  class="heading {{ block.settings.heading_size }}"
  {{ block.shopify_attributes }}
>
  {{ block.settings.heading }}
</{{ block.settings.heading_tag | default: 'h2' }}>
```

## Conditional Rendering

### Feature flags via theme settings

```liquid
{% liquid
  assign show_vendor = settings.show_vendor
  assign show_sku = settings.show_sku
  assign show_quantity_selector = section.settings.show_quantity_selector
%}

{% if show_vendor and product.vendor != blank %}
  <p class="product-vendor text-sm text-gray-500">{{ product.vendor }}</p>
{% endif %}
```

### Template-specific content

```liquid
{% liquid
  case template.name
    when 'product'
      assign page_type = 'product'
    when 'collection'
      assign page_type = 'collection'
    when 'index'
      assign page_type = 'home'
    else
      assign page_type = 'page'
  endcase
%}
```

## Metafield Access

### Product metafields

```liquid
{% liquid
  assign size_guide = product.metafields.custom.size_guide.value
  assign care_instructions = product.metafields.custom.care_instructions.value
  assign material = product.metafields.custom.material.value
%}

{% if size_guide != blank %}
  <div class="size-guide">
    {{ size_guide }}
  </div>
{% endif %}
```

### Metaobject references

```liquid
{% liquid
  assign designer = product.metafields.custom.designer.value
%}

{% if designer != blank %}
  <div class="designer-info">
    <h3>{{ designer.name.value }}</h3>
    {% if designer.portrait.value %}
      {{ designer.portrait.value | image_url: width: 200 | image_tag: loading: 'lazy' }}
    {% endif %}
    <p>{{ designer.bio.value }}</p>
  </div>
{% endif %}
```

## Image Optimization

### Responsive images with Shopify CDN

```liquid
{% liquid
  assign image = product.featured_image
  assign image_alt = image.alt | escape | default: product.title | escape
%}

{% if image %}
  <img
    src="{{ image | image_url: width: 800 }}"
    srcset="
      {{ image | image_url: width: 400 }} 400w,
      {{ image | image_url: width: 600 }} 600w,
      {{ image | image_url: width: 800 }} 800w,
      {{ image | image_url: width: 1200 }} 1200w
    "
    sizes="(max-width: 640px) 100vw, (max-width: 1024px) 50vw, 33vw"
    alt="{{ image_alt }}"
    width="{{ image.width }}"
    height="{{ image.height }}"
    loading="lazy"
  >
{% endif %}
```

### Above-fold hero image (no lazy loading)

```liquid
{{
  section.settings.hero_image
  | image_url: width: 1920
  | image_tag:
    loading: 'eager',
    fetchpriority: 'high',
    sizes: '100vw',
    widths: '375, 750, 1100, 1500, 1920',
    alt: section.settings.hero_heading
}}
```

## Filter Chains

### Price formatting

```liquid
{% liquid
  assign current_price = product.price | money
  assign compare_price = product.compare_at_price | money
  assign savings_percent = product.compare_at_price | minus: product.price | times: 100.0 | divided_by: product.compare_at_price | round
%}

{% if product.compare_at_price > product.price %}
  <span class="price--sale">{{ current_price }}</span>
  <span class="price--compare line-through">{{ compare_price }}</span>
  <span class="price--savings">{{ savings_percent }}% off</span>
{% else %}
  <span class="price">{{ current_price }}</span>
{% endif %}
```

### String manipulation

```liquid
{% liquid
  assign handle = product.title | handleize
  assign truncated_desc = product.description | strip_html | truncate: 150
  assign word_count = product.description | strip_html | split: ' ' | size
%}
```

## Common Anti-Patterns

### Repeating expensive operations

```liquid
{% comment %} BAD: Calls image_url twice with same params {% endcomment %}
<img src="{{ product.featured_image | image_url: width: 800 }}">
<meta property="og:image" content="{{ product.featured_image | image_url: width: 800 }}">

{% comment %} GOOD: Assign once, use twice {% endcomment %}
{% assign featured_image_url = product.featured_image | image_url: width: 800 %}
<img src="{{ featured_image_url }}">
<meta property="og:image" content="{{ featured_image_url }}">
```

### Unbounded loops

```liquid
{% comment %} BAD: No limit on potentially huge collection {% endcomment %}
{% for product in collections.all.products %}

{% comment %} GOOD: Always limit or paginate {% endcomment %}
{% for product in collections.all.products limit: 12 %}
```

### Using `include` instead of `render`

```liquid
{% comment %} BAD: include shares parent scope (deprecated) {% endcomment %}
{% include 'product-card' %}

{% comment %} GOOD: render creates isolated scope {% endcomment %}
{% render 'product-card', product: product %}
```

### Inline JavaScript

```liquid
{% comment %} BAD: Inline event handlers {% endcomment %}
<button onclick="addToCart({{ product.id }})">Add to Cart</button>

{% comment %} GOOD: Data attributes + external TypeScript {% endcomment %}
<button data-add-to-cart="{{ product.id }}">Add to Cart</button>
```

### Deeply nested conditionals

```liquid
{% comment %} BAD: Hard to read and maintain {% endcomment %}
{% if product.available %}
  {% if product.variants.size > 1 %}
    {% if product.selected_variant %}
      ...
    {% endif %}
  {% endif %}
{% endif %}

{% comment %} GOOD: Use liquid tag with early returns {% endcomment %}
{% liquid
  unless product.available
    render 'product-unavailable'
    break
  endunless

  if product.variants.size == 1
    render 'product-single-variant', product: product
    break
  endif

  render 'product-variant-selector', product: product
%}
```
