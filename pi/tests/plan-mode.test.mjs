import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { createRequire } from "node:module";
import test from "node:test";

const agentDir = join(homedir(), ".pi/agent");
const version = readFileSync(join(agentDir, "install/current-version"), "utf8").trim();
const requirePi = createRequire(join(agentDir, "install/releases", version, "package.json"));
const { createJiti } = requirePi("jiti");
const jiti = createJiti(import.meta.url, { fsCache: false, moduleCache: false });
const { default: install } = await jiti.import("../.pi/agent/extensions/plan-mode.ts");

const target = { provider: "openai", id: "gpt-6.1-sol" };
const builtIn = (name) => ({ name, exposure: "direct", sourceInfo: { path: `builtin:${name}` } });
const mcp = (name) => ({ name, exposure: "direct", sourceInfo: { path: "builtin:mcp" } });
const initial = ["read", "bash", "edit", "write", "codemode", "tool_search", "mcp__parallel__web_search", "mcp__parallel__web_fetch"];

function harness(options = {}) {
	const hooks = new Map();
	const commands = new Map();
	const shortcuts = new Map();
	const entries = structuredClone(options.entries ?? []);
	const notices = [];
	const statuses = new Map();
	let active = [...initial];
	let thinking = "low";
	let idle = true;
	let available = options.available !== false;
	let authenticated = options.authenticated !== false;
	const tools = [
		...["read", "grep", "find", "ls", "bash", "edit", "write", "codemode", "tool_search"].map(builtIn),
		mcp("mcp__parallel__web_search"), mcp("mcp__parallel__web_fetch"),
		mcp("mcp__other__delete"),
		{ name: "unsafe", exposure: "direct", annotations: { readOnlyHint: true }, sourceInfo: { path: "/unsafe.ts" } },
	];
	const ctx = {
		model: options.model ?? target,
		mode: "rpc",
		isIdle: () => idle,
		sessionManager: { getBranch: () => entries },
		modelRegistry: { find: () => available ? target : undefined, hasConfiguredAuth: () => authenticated },
		ui: {
			notify: (message, kind) => notices.push({ message, kind }),
			setStatus: (key, value) => value ? statuses.set(key, value) : statuses.delete(key),
		},
	};
	const pi = {
		on: (event, callback) => hooks.set(event, callback),
		registerCommand: (name, command) => commands.set(name, command),
		registerShortcut: (key, shortcut) => shortcuts.set(key, shortcut),
		registerFlag: () => {},
		getFlag: () => options.flag === true,
		getSettings: () => ({ defaultProvider: "openai", defaultModel: "gpt-6.1-sol" }),
		getActiveTools: () => active,
		getAllTools: () => tools,
		setActiveTools: (names) => { active = [...names]; },
		setThinkingLevel: (level) => { thinking = level; },
		setModel: async (model) => { if (!authenticated) return false; ctx.model = model; return true; },
		appendEntry: (customType, data) => entries.push({ type: "custom", customType, data: structuredClone(data) }),
	};
	install(pi);
	return {
		ctx, pi, entries, tools, notices, statuses,
		event: (name, data = {}) => hooks.get(name)?.(data, ctx),
		command: (args = "") => commands.get("plan").handler(args, ctx),
		shortcut: (key) => shortcuts.get(key).handler(ctx),
		active: () => active,
		thinking: () => thinking,
		idle: (value) => { idle = value; },
		authenticate: () => { authenticated = true; available = true; },
	};
}

test("startup selects OpenAI / low, even if Pi selected a provider fallback", async () => {
	const h = harness({ model: { provider: "openrouter", id: "other" } });
	await h.event("session_start", { reason: "startup" });
	assert.deepEqual(h.ctx.model, target);
	assert.equal(h.thinking(), "low");
	assert.deepEqual(h.active(), initial);
});

test("on/off and toggle change reasoning, tools and visible status without stale prompt", async () => {
	const h = harness();
	await h.command("on");
	assert.equal(h.thinking(), "medium");
	assert.ok(h.statuses.get("plan-mode").includes("PLAN"));
	assert.deepEqual(h.active(), ["read", "grep", "find", "ls", "mcp__parallel__web_search", "mcp__parallel__web_fetch"]);
	assert.match((await h.event("before_agent_start", { systemPrompt: "BASE" })).systemPrompt, /BASE\n.*PLAN MODE/s);
	await h.command("on"); // idempotent: preserve original normal tool snapshot
	await h.command("off");
	assert.equal(h.thinking(), "low");
	assert.deepEqual(h.active(), initial);
	assert.equal(h.statuses.has("plan-mode"), false);
	assert.equal(await h.event("before_agent_start", { systemPrompt: "BASE" }), undefined);
	await h.command();
	assert.equal(h.thinking(), "medium");
});

test("plan persists across resume, reload and fork; --plan persists on startup", async () => {
	const h = harness();
	await h.command("on");
	for (const reason of ["resume", "reload", "fork"]) {
		const resumed = harness({ entries: h.entries });
		await resumed.event("session_start", { reason });
		assert.equal(resumed.thinking(), "medium");
		assert.ok(!resumed.active().includes("write"));
		await resumed.command("off");
		assert.deepEqual(resumed.active(), initial);
	}
	const flagged = harness({ flag: true });
	await flagged.event("session_start", { reason: "startup" });
	assert.equal(flagged.thinking(), "medium");
	assert.equal(flagged.entries.at(-1).data.enabled, true);
});

test("direct and nested mutations, shell and untrusted read-only hints are blocked", async () => {
	const h = harness();
	await h.command("on");
	for (const toolName of ["bash", "write", "edit", "codemode", "tool_search", "unsafe", "mcp__other__delete", "unknown"]) {
		for (const parentToolCallId of [undefined, "orchestrator"]) {
			assert.equal((await h.event("tool_call", { toolName, parentToolCallId })).block, true);
		}
	}
	for (const toolName of ["read", "grep", "find", "ls", "mcp__parallel__web_search", "mcp__parallel__web_fetch"]) {
		assert.equal(await h.event("tool_call", { toolName }), undefined);
	}
	assert.equal((await h.event("user_bash", { command: "touch /tmp/unwanted", excludeFromContext: true })).result.exitCode, 1);
	h.tools.push(mcp("mcp__new__write"));
	h.pi.setActiveTools([...h.active(), "mcp__new__write"]);
	await h.event("mcp_servers_change");
	assert.ok(!h.active().includes("mcp__new__write"));
	await h.command("off");
	assert.equal(await h.event("tool_call", { toolName: "write" }), undefined);
	assert.equal(await h.event("user_bash"), undefined);
});

test("invalid args and mode changes during streaming leave state alone", async () => {
	const h = harness();
	await h.command("invalid");
	h.idle(false);
	await h.command("on");
	assert.equal(h.thinking(), "low");
	assert.equal(h.entries.length, 0);
	assert.deepEqual(h.active(), initial);
});

test("missing OpenAI auth/model cannot trigger fallback or leave resumed plan writable", async () => {
	for (const options of [{ authenticated: false }, { available: false }]) {
		const h = harness({ ...options, model: { provider: "openrouter", id: "other" } });
		await h.event("session_start", { reason: "startup" });
		assert.equal((await h.event("input", { text: "hello" })).action, "handled");
		await h.command("on");
		assert.equal(h.entries.length, 0);
		h.authenticate();
		assert.equal((await h.event("input", { text: "hello" })).action, "continue");
		assert.deepEqual(h.ctx.model, target);
	}
	const planned = harness();
	await planned.command("on");
	const resumed = harness({ authenticated: false, entries: planned.entries });
	await resumed.event("session_start", { reason: "resume" });
	assert.ok(!resumed.active().includes("write"));
	await resumed.command("off");
	assert.ok(!resumed.active().includes("write"));
});

test("plan input restores target model and medium after manual model/thinking changes", async () => {
	const h = harness();
	await h.command("on");
	h.ctx.model = { provider: "openrouter", id: "other" };
	h.pi.setThinkingLevel("high");
	await h.event("input", { text: "plan this" });
	assert.deepEqual(h.ctx.model, target);
	assert.equal(h.thinking(), "medium");
});

test("navigating to a branch before plan mode restores normal reasoning and status", async () => {
	const h = harness();
	await h.command("on");
	h.entries.length = 0; // Target branch predates the plan entry.
	await h.event("session_tree");
	assert.equal(h.thinking(), "low");
	assert.deepEqual(h.active(), initial);
	assert.equal(h.statuses.has("plan-mode"), false);
	assert.equal(await h.event("tool_call", { toolName: "write" }), undefined);
});

test("Shift+Tab toggles plan mode instead of cycling reasoning", async () => {
	const bindings = JSON.parse(readFileSync(new URL("../.pi/agent/keybindings.json", import.meta.url), "utf8"));
	assert.deepEqual(bindings["app.thinking.cycle"], []);
	const h = harness();
	await h.shortcut("shift+tab");
	assert.equal(h.thinking(), "medium");
	assert.ok(!h.active().includes("write"));
	await h.shortcut("shift+tab");
	assert.equal(h.thinking(), "low");
	assert.deepEqual(h.active(), initial);
});
