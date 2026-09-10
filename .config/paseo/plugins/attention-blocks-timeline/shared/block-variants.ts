/** Semantic card palette tuned for Zinc dark. */
export const BLOCK_VARIANTS = {
  neutral: { stripeColor: "#6ea8fe" },
  message: { stripeColor: "#b197fc" },
  action: { stripeColor: "#fb923c" },
  warning: { stripeColor: "#fbbf24" },
  error: { stripeColor: "#f87171" },
  success: { stripeColor: "#34d399" },
} as const;

export type BlockVariant = (typeof BLOCK_VARIANTS)[keyof typeof BLOCK_VARIANTS];
export type BlockVariantName = keyof typeof BLOCK_VARIANTS;

type VariantRule = { variant: BlockVariantName; pattern: RegExp };

const SEMANTIC_RULES: readonly VariantRule[] = [
  {
    variant: "success",
    pattern: /\b(pass(?:ed|ing)?|success(?:ful|fully)?|fixed|done|complete(?:d)?|working|running|merged|landed|shipped|resolved|verified|healthy)\b/i,
  },
  {
    variant: "warning",
    pattern: /\b(warn(?:ing)?|risk|caution|careful|concern|danger|unsafe|avoid)\b/i,
  },
  {
    variant: "error",
    pattern: /\b(error|failed|failure|broken|blocked|cannot|can't|impossible|fatal|bug|regression)\b/i,
  },
  {
    variant: "action",
    pattern: /\b(next|step|plan|todo|action|setting|setup|install|reload|configure|command)\b/i,
  },
  {
    variant: "message",
    pattern: /\b(message|reasoning|thinking|ui|design|display|appearance|summary|note|information|update)\b/i,
  },
];

function classify(text: string): BlockVariantName | null {
  for (const rule of SEMANTIC_RULES) {
    if (rule.pattern.test(text)) return rule.variant;
  }
  return null;
}

/** Title semantics take priority so a successful card stays green when its body mentions errors. */
export function blockVariantName(title: string, body = ""): BlockVariantName {
  return classify(title) ?? classify(body) ?? "neutral";
}

export function blockVariant(title: string, body = ""): BlockVariant {
  return BLOCK_VARIANTS[blockVariantName(title, body)];
}
