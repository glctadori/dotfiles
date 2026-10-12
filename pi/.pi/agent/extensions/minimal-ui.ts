/**
 * minimal-ui - a small, reversible terminal UI reduction for Pi.
 *
 * What it changes (rendering only; tools and keybindings keep working):
 * 1. Footer: shows mode, reasoning level, provider/model, and context usage percentage.
 * 2. Tool results: hidden while collapsed, except error results, which stay
 *    visible. Press ctrl+o (app.tools.expand) to reveal the full output.
 * The native editor keeps its layout, autocomplete, and resize handling.
 *
 * Disable by removing this file from the `extensions` setting in settings.json.
 */

import type {
	AgentToolResult,
	ExtensionAPI,
	ExtensionContext,
	Theme,
	ToolRenderResultOptions,
} from "@earendil-works/pi-coding-agent";
import { Text, truncateToWidth } from "@earendil-works/pi-tui";

/** Preview cap for the generic fallback, matching Pi's built-in collapsed view. */
const PREVIEW_LINES = 10;

/**
 * Render a tool result for tools that have no registered renderer. Used only
 * when the result is expanded or is an error, since normal collapsed output is
 * hidden above.
 */
function renderGenericResult(
	result: AgentToolResult<unknown>,
	options: ToolRenderResultOptions,
	theme: Theme,
): Text {
	const text = result.content
		.filter((c): c is { type: "text"; text: string } => c.type === "text")
		.map((c) => c.text)
		.join("\n");

	if (!text) return new Text("", 0, 0);

	const lines = text.split("\n");
	const shown = options.expanded ? lines : lines.slice(0, PREVIEW_LINES);
	const remaining = lines.length - shown.length;

	let output = shown.map((line) => theme.fg("toolOutput", line)).join("\n");
	if (remaining > 0) {
		output += theme.fg("muted", `\n... (${remaining} more lines, ctrl+o to expand)`);
	}
	return new Text(output, 0, 0);
}

export default function (pi: ExtensionAPI) {
	// Kitty's copy overlay reads the saved active branch, not only fullscreen's viewport.
	// Publish two small identifiers; no transcript export or disk work during rendering.
	let copySourceActive = false;
	function publishCopySource(ctx: ExtensionContext): void {
		if (!copySourceActive) return;
		const metadata = Buffer.from(JSON.stringify({
			file: ctx.sessionManager.getSessionFile(), leaf: ctx.sessionManager.getLeafId(),
		})).toString("base64");
		process.stdout.write(`\x1b]1337;SetUserVar=pi_copy_session=${metadata}\x07`);
	}
	pi.on("session_start", (_event, ctx) => {
		copySourceActive = ctx.mode === "tui" && !!process.env.KITTY_WINDOW_ID;
		publishCopySource(ctx);
	});
	pi.on("agent_settled", (_event, ctx) => publishCopySource(ctx));
	pi.on("session_tree", (_event, ctx) => publishCopySource(ctx));
	pi.on("session_shutdown", () => {
		if (copySourceActive) process.stdout.write("\x1b]1337;SetUserVar=pi_copy_session\x07");
		copySourceActive = false;
	});

	// Wrap every tool's result renderer: hide normal collapsed output, keep
	// errors visible, and delegate expanded output to the original renderer.
	pi.registerToolRenderer((_toolName, next) => {
		const base = next();
		const baseRenderResult = base?.renderResult;

		return {
			...base,
			renderResult(result, options, theme, context) {
				if (!options.expanded && !result.isError && !context.isError) {
					return new Text("", 0, 0);
				}
				if (baseRenderResult) {
					return baseRenderResult.call(base, result, options, theme, context);
				}
				return renderGenericResult(result, options, theme);
			},
		};
	});

	pi.on("session_start", (_event, ctx) => {
		if (ctx.mode !== "tui") return;

		// Keep mode and reasoning visible first in narrow terminals.
		ctx.ui.setFooter((_tui, theme, footerData) => ({
			invalidate() {},
			render(width: number): string[] {
				const model = ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : "no-model";
				const mode = footerData.getExtensionStatuses().get("plan-mode");
				const thinking = ctx.thinkingLevel ?? "?";
				const usage = ctx.getContextUsage();
				const percent = usage?.percent == null ? "?" : `${usage.percent.toFixed(1)}%`;
				const label = theme.fg(mode ? "warning" : "muted", `${mode ? "PLAN" : "NORMAL"} · ${thinking}`);
				const line = `${label}  ${theme.fg("muted", model)}  ${theme.fg("muted", `contesto ${percent}`)}`;
				return [truncateToWidth(line, width, "")];
			},
		}));
	});
}
