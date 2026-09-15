/**
 * Pick a Lucide icon from block title/body. Returns null when nothing fits —
 * stripe-only cards stay clean for generic prose.
 */
type IconRule = { icon: string; pattern: RegExp };

const ICON_RULES: IconRule[] = [
  { icon: "CircleX", pattern: /\b(not possible|cannot|can't|won't work|impossible|no way)\b/i },
  { icon: "CircleCheck", pattern: /\b(yes[,—]|possible|can do|works|fixed|done|complete|shipped|committed)\b/i },
  { icon: "AlertTriangle", pattern: /\b(warn|caution|risk|careful|avoid|don't|never|critical)\b/i },
  { icon: "Bug", pattern: /\b(bug|broken|fix(ed)?|root cause|issue|error|duplicate|dup|parser)\b/i },
  { icon: "Palette", pattern: /\b(theme|color|colour|zinc|appearance|palette|tint)\b/i },
  { icon: "Sparkles", pattern: /\b(icon|visual|design|look(s)?|ui|render|prettier|better)\b/i },
  { icon: "GitCommit", pattern: /\b(commit|git|ship|push|branch|merge|pr\b|pull request)\b/i },
  { icon: "Puzzle", pattern: /\b(plugin|extension|timeline|transformer|paseo)\b/i },
  { icon: "ListChecks", pattern: /\b(next|step|plan|recommend(ed)?|should|todo|checklist|order)\b/i },
  { icon: "Settings", pattern: /\b(setup|config|setting|install|enable|reload)\b/i },
  { icon: "Lightbulb", pattern: /\b(idea|tip|note|remember|why|because|insight)\b/i },
  { icon: "Shield", pattern: /\b(security|safe|guard|protect|permission)\b/i },
  { icon: "Zap", pattern: /\b(fast|quick|perf|performance|optimize|speed)\b/i },
  { icon: "Info", pattern: /\b(what|how|explain|overview|summary|bottom line)\b/i },
];

function firstMatch(text: string): string | null {
  for (const rule of ICON_RULES) {
    if (rule.pattern.test(text)) return rule.icon;
  }
  return null;
}

export function inferBlockIcon(title: string, body: string): string | null {
  return firstMatch(title) ?? firstMatch(body);
}
