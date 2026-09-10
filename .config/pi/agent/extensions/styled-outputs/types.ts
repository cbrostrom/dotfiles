export type MessageStyle = "prefix" | "framed" | "labeled";

/** @deprecated Use MessageStyle */
export type UserMessageStyle = MessageStyle;

export interface AttentionBlocksUserConfig {
  /** Parse **→ Lead-in.** paragraphs into tinted boxes. Default: true. */
  enabled?: boolean;
  /** Interior tint. Default: customMessageBg */
  backgroundColor?: string;
  borderColor?: string;
  accentColor?: string;
}

export interface AssistantMessageUserConfig {
  /** Visual wrap style. Default: framed. */
  style?: MessageStyle;
  prefix?: string;
  /** Left rail glyph used by framed style. Default: │ */
  rail?: string;
  color?: string;
  /** Rule / box border color. Default: border */
  borderColor?: string;
  attentionBlocks?: AttentionBlocksUserConfig;
}

export interface UserMessageUserConfig {
  /** Visual wrap style. Default: framed (zentui-inspired rules + rail). */
  style?: MessageStyle;
  prefix?: string;
  /** Left rail glyph used by framed style. Default: │ */
  rail?: string;
  color?: string;
  /** Rule / box border color. Default: border */
  borderColor?: string;
  bodyColor?: string;
  isThemeBackgroundVisible?: boolean;
}

export interface SkillsUserConfig {
  prefix?: string;
  prefixColor?: string;
  titleColor?: string;
  nameColor?: string;
  labelColor?: string;
  expandHintColor?: string;
  outputColor?: string;
}

export interface ThinkingMessageUserConfig {
  /** Visual wrap style. Default: labeled (closed box with Thinking title). */
  style?: MessageStyle;
  prefix?: string;
  /** Left rail glyph used by framed style. Default: │ */
  rail?: string;
  prefixColor?: string;
  /** Rule / box border color. Default: borderMuted */
  borderColor?: string;
  label?: string;
  labelColor?: string;
  isLabelVisible?: boolean;
  messageColor?: string;
}

export interface ToolSpinnerPrefixUserConfig {
  prefixChars?: string[];
  color?: string;
}

export interface ToolSuccessUserConfig {
  prefix?: string;
  prefixColor?: string;
  labelColor?: string;
}

export interface ToolErrorUserConfig {
  prefix?: string;
  prefixColor?: string;
  labelColor?: string;
}

export interface ToolBranchUserConfig {
  prefix?: string;
  color?: string;
}

export type TrimStrategy = "head" | "tail" | "head-tail";

export interface ToolGeneralUserConfig {
  titleColor?: string;
  summaryColor?: string;
  countColor?: string;
  expandHintColor?: string;
  outputColor?: string;
  isThemeBackgroundVisible?: boolean;
  verticalPadding?: number;
  horizontalPadding?: number;
  maxExpandedLines?: number;
  moreColor?: string;
  moreBgColor?: string;
  diffAddedColor?: string;
  diffRemovedColor?: string;
  diffContextColor?: string;
  maxDiffFileSize?: string | number;
}

export interface ToolGroupsUserConfig {
  base?: ToolGeneralUserConfig;
  mcp?: ToolGeneralUserConfig;
  web?: ToolGeneralUserConfig;
  custom?: ToolGeneralUserConfig;
}

export interface ToolsUserConfig {
  toolSpinnerPrefix?: ToolSpinnerPrefixUserConfig;
  toolSuccess?: ToolSuccessUserConfig;
  toolError?: ToolErrorUserConfig;
  toolBranch?: ToolBranchUserConfig;
  general?: ToolGeneralUserConfig;
  groups?: ToolGroupsUserConfig;
}

export interface BashExecutionUserConfig {
  titleColor?: string;
}

export interface CustomMessagesUserConfig {
  prefix?: string;
  prefixColor?: string;
  titleColor?: string;
  nameColor?: string;
  labelColor?: string;
  expandHintColor?: string;
  outputColor?: string;
}

export interface StyledOutputsUserConfig {
  assistantMessage?: AssistantMessageUserConfig;
  userMessage?: UserMessageUserConfig;
  skills?: SkillsUserConfig;
  thinkingMessage?: ThinkingMessageUserConfig;
  customMessages?: CustomMessagesUserConfig;
  bashExecution?: BashExecutionUserConfig;
  tools?: ToolsUserConfig;
}