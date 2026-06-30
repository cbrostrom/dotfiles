---
name: shopify
description: Shared Shopify platform knowledge for all agents. Covers evidence standard, MCP-first verification, vault routing for Shopify work, complexity assessment, and forbidden phrases. Load this skill when any Shopify platform question, implementation, or context lookup is involved.
---

# Shopify Shared Skill

Foundation layer for all Shopify-related agent work. Load before answering Shopify questions, planning Shopify implementations, or reading Shopify project context.

## MCP-First Verification

Always verify Shopify platform behavior through Shopify MCP documentation before making claims.

Do not answer from memory when MCP can settle the question. Do not invent:
- Liquid object properties, filters, or tag behavior
- API fields, rate limits, scopes, or deprecation status
- Schema attributes, section/block behavior, or theme constraints
- Checkout, market, or subscription platform behavior

If MCP does not confirm a claim, say so explicitly.

## Evidence Standard

Every meaningful conclusion must be grounded as one of:

- Verified by Shopify MCP documentation
- Verified by local repository evidence
- Verified by command output, validation, tests, or runtime behavior
- Unknown or unverified

Never blend these categories. If a claim cannot be verified, name the gap.

**Forbidden phrases** (replace with evidence or explicit unknowns):
- "I think this will work"
- "This should probably work"
- "Shopify usually does..."
- "It seems like..."
- "I assume..."
- "Simply" / "just" / "typically"

## Vault Routing for Shopify Work

When you need project context, load in this order — cheapest first:

1. **Brain** (`~/Vaults/AI/brains/<slug>/current.md`) — current project state, active decisions, gotchas
2. **Durable Shopify knowledge** (`~/Vaults/Me/Work/AKQA/Shopify/`) — headless research, architectural decisions, reusable patterns
3. **Client-specific** (`~/Vaults/Me/Work/AKQA/Shopify/Fiskars/`) — Fiskars-specific notes, only when the task is Fiskars-specific
4. **Cross-cutting technical** (`~/Vaults/Me/Development/`) — framework notes, model selection, general patterns

Use frontmatter (`client:`, `area:`, `type:`) and filenames to narrow before reading. Never read a full folder when a filename match will do.

Do not mix client-specific context into general Shopify reasoning. The brain carries state, not the full architecture essay.

## Complexity Assessment

When implementation follows from an answer, output a model recommendation:

```yaml
model_recommendation:
  primary: "Sonnet 4.6"
  fallback: "Opus 4.8"
  budget_tier: "high"
  why: "Reason the primary handles this without over-spending."
  escalate_if:
    - "platform behavior is undocumented or ambiguous"
    - "multi-market, checkout, or subscription scope emerges"
    - "cross-store or architecture-level changes required"
```

Reference tiers (full map: `~/Vaults/Me/Development/Cursor Model Selection Map.md`):

| Complexity | Criteria | Tier |
|---|---|---|
| Trivial | Single Liquid tag/filter, one-file, obvious fix | Cheap (GPT Mini / Haiku) |
| Low | Section/block schema, straightforward API call | Economical (Composer 2.5 / Codex) |
| Medium | Multi-section, API migration, metafield architecture | Senior (Sonnet 4.6 / Codex 5.3) |
| High | Checkout extensibility, multi-market, theme architecture | Premium (Opus 4.8 / GPT-5.5) |

## Approval Gate

Before implementing or editing files:
1. State the complexity level and model recommendation.
2. Present the plan and risk.
3. Ask for permission unless the user explicitly said to proceed.

Do not treat documentation lookup as permission to edit code.
