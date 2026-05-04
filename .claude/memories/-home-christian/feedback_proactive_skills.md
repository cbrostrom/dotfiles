---
name: Proaktiv brug af skills og MCP-plugins
description: Brugeren ønsker at Claude aktivt bruger skills og MCP-plugins baseret på nøgleord i konteksten
type: feedback
originSessionId: 6edb1b5d-97e2-4bb6-83bc-4edef4ab61e8
---
Brug skills og MCP-plugins proaktivt baseret på nøgleord — vent ikke på eksplicit forespørgsel.

**Why:** Brugeren vil have at toolkassen bruges automatisk, ikke kun når han spørger direkte.

**How to apply:**
- "Shopify" / "Liquid" / "theme" / "store" → invoker `shopify-theme-development` skill + `mcp__plugin_shopify-plugin_shopify-mcp__learn_shopify_api` + `search_docs_chunks`
- "design" / "UI" / "frontend" → invoker `frontend-design` skill
- "CSS" / "Tailwind" → invoker `tailwind-css-patterns` skill
- "accessibility" / "a11y" → invoker `accessibility` skill
- "TypeScript" / avancerede typer → invoker `typescript-advanced-types` skill
- "git" / "commit" → invoker `caveman:caveman-commit` skill
- "Jira" / "Confluence" / "Atlassian" → invoker relevante `atlassian:*` skills
- Altid: tjek om et task/feature request matcher en skill FØR du svarer
