/**
 * Pi Welcome Header — themed startup chrome.
 *
 * Replaces Pi's built-in header so the logo, version, model, cwd, and usual
 * help text appear before Pi's native loaded resources listing.
 */

import fs from "node:fs";
import path from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

type Rgb = [number, number, number];

const RESET = "\x1b[0m";
const PALETTE: Rgb[] = [
	[22, 83, 189],
	[48, 129, 247],
	[93, 171, 255],
	[151, 205, 255],
	[93, 171, 255],
	[48, 129, 247],
];
const TITLE_LINES = [
	"  ██████╗  ██╗ ",
	"  ██╔══██╗ ██║ ",
	"  ██████╔╝ ██║ ",
	"  ██╔═══╝  ██║ ",
	"  ██║      ██║ ",
	"  ╚═╝      ╚═╝ ",
];

function mix(a: number, b: number, amount: number) {
	return Math.round(a + (b - a) * amount);
}

function sampleGradient(position: number): Rgb {
	const wrapped = ((position % 1) + 1) % 1;
	const scaled = wrapped * PALETTE.length;
	const index = Math.floor(scaled);
	const nextIndex = (index + 1) % PALETTE.length;
	const amount = scaled - index;
	const start = PALETTE[index]!;
	const end = PALETTE[nextIndex]!;
	return [
		mix(start[0], end[0], amount),
		mix(start[1], end[1], amount),
		mix(start[2], end[2], amount),
	];
}

function foreground([red, green, blue]: Rgb, text: string) {
	return `\x1b[38;2;${red};${green};${blue}m${text}${RESET}`;
}

function gradientText(text: string, phase: number) {
	const characters = [...text];
	const span = Math.max(characters.length - 1, 1);
	return characters
		.map((character, index) =>
			character === " "
				? character
				: foreground(sampleGradient(index / span + phase), character),
		)
		.join("");
}


function compactCwd(cwd: string): string {
	const home = process.env.HOME;
	if (home && cwd.startsWith(home)) return cwd.replace(home, "~");
	return cwd;
}

function projectName(cwd: string): string {
	return path.basename(cwd) || "session";
}

function welcomeConfigPath(): string {
	return path.join(process.env.PI_HOME || path.join(process.env.HOME || "", ".pi", "agent"), "welcome.json");
}

function setWelcomeUpdates(enabled: boolean) {
	const file = welcomeConfigPath();
	let config: Record<string, unknown> = {};
	try {
		config = JSON.parse(fs.readFileSync(file, "utf8"));
	} catch {}
	config.updates = enabled;
	fs.mkdirSync(path.dirname(file), { recursive: true });
	fs.writeFileSync(file, `${JSON.stringify(config, null, "\t")}\n`);
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", (_event, ctx) => {
		if (ctx.mode !== "tui") return;

		const dir = compactCwd(ctx.cwd ?? process.cwd());
		const model = ctx.model?.id ?? "no model";

		ctx.ui.setHeader((_tui, theme) => ({
			render(width: number): string[] {
				const pad = (s: string, w: number) => {
					const vis = visibleWidth(s);
					const left = Math.floor((w - vis) / 2);
					return " ".repeat(Math.max(0, left)) + s;
				};
				const art = TITLE_LINES.map((line, row) =>
					pad(gradientText(line, row * 0.045), width),
				);
				const rule     = theme.fg("dim", "─".repeat(Math.min(width, 36)));
				const infoLine = `${theme.fg("accent", model)} ${theme.fg("dim", "·")} ${theme.fg("accent", projectName(dir))}`;
				const lines = [
					"",
					...art,
					"",
					pad(rule, width),
					pad(infoLine, width),
					"",
				];
				return lines.map((line) => visibleWidth(line) > width ? truncateToWidth(line, width) : line);
			},
			invalidate() {},
		}));
	});

	pi.registerCommand("welcome", {
		description: "Configure the startup welcome header",
		handler: async (args, ctx) => {
			const normalized = args.trim().toLowerCase();
			if (normalized === "updates on") {
				setWelcomeUpdates(true);
				ctx.ui.notify("Welcome update notices enabled for future sessions", "info");
				return;
			}
			if (normalized === "updates off") {
				setWelcomeUpdates(false);
				ctx.ui.notify("Welcome update notices disabled for future sessions", "info");
				return;
			}
			ctx.ui.notify("Usage: /welcome updates on | /welcome updates off", "info");
		},
	});

	pi.on("session_shutdown", (_event, ctx) => {
		if (ctx.hasUI) ctx.ui.setHeader(undefined);
	});
}
