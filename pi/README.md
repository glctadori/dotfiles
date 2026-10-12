# Pi

Stow package for Pi 1.1.0 or newer: settings, the minimal terminal UI, and
web research using Parallel's built-in MCP integration, and local plan mode.

```sh
stow --restow --target="$HOME" pi
pi mcp list
pi
```

Existing regular files at the target paths must be backed up and moved out of
the way before Stow can link them. Keep the existing `.pi/agent` directory:
credentials, sessions, installation data, and other runtime files stay there.

Parallel uses anonymous access with reduced rate limits and `fast` search.
No API key is required. The model selected in Pi calls the search and fetch
tools directly. See https://docs.parallel.ai/integrations/mcp/search-mcp.

Try `/skill:web-research Cerca libri e documenti autorevoli sul tema X`.
In an already running Pi session, use `/reload` after changing resources.

New sessions default to `openai/gpt-6.1-sol` with `low` reasoning. OpenAI uses
the existing provider authentication (`/login openai` if needed), not OpenRouter.

Use Shift+Tab or `/plan` to toggle planning, `/plan on` to enter, and `/plan off` to leave.
The keybindings file clears Shift+Tab's built-in thinking-cycle assignment so
one press changes mode once, with the mode's required reasoning level.
`pi --plan` starts in planning mode. Planning selects the same OpenAI model with
`medium` reasoning; leaving selects it with `low`. The footer shows the mode,
provider, model, and reasoning. Saved sessions remember their planning mode.

Planning allows built-in file reading/search and Parallel web search/fetch.
It blocks shell commands (including `!`/`!!`), file writes, and other tools,
including indirect calls. It asks questions and produces a plan; it never
automatically executes one. Exit planning explicitly before implementation.
Unavailable OpenAI authentication/model is reported instead of silently routing
planning requests to another provider. Other models remain selectable normally.

Only configuration, local extensions, documentation/tests, and the web-research
skill belong in this package. Never copy the whole agent directory into it.
Pi may update its linked settings file; review changes before committing.
The Neovim chat integration is configured separately.

The default TUI mode is `fullscreen`, with Pi's native editor. This keeps resize
and autocomplete geometry under Pi's control; the extension does not remove
rows from the editor's rendered layout. Scroll the transcript with Page Up /
Page Down or the mouse wheel. The compact footer and Shift+Tab plan toggle
remain available. Restart Pi after changing the TUI mode.

Kitty's `Super+Y` (also `Ctrl+Shift+H`) opens a lightweight Neovim copy overlay.
The Kitty dotfiles package provides `copy-mode.py` and `copy-mode.lua`. Pi's
minimal UI publishes the current saved session file and active branch ID via
a Kitty user variable; the overlay reads the user/assistant messages from that
branch, including original LaTeX. It does not copy tool output or hidden thinking.
While a response is streaming, the saved completed conversation is used. Before
the first response is saved, or with `--no-session`, the visible terminal text
is used instead. Outside Pi, it shows Kitty's screen and scrollback.

Use `hjkl` / `gg` / `G`, `/` to search, `v` / `V` to select, and `y` / `yy` to
copy to the system clipboard. `q` closes the overlay and returns to Pi. The
temporary copy is private and removed when the viewer closes; the original
session is untouched. Neovim uses a dedicated minimal config without plugins.

Run the local regression checks with `node --test pi/tests/plan-mode.test.mjs`
from the dotfiles root. They use the `jiti` already installed with managed Pi.
No additional dependencies or model calls are needed for those checks.

Startup measurements on 2026-10-12 used five interleaved launches per setup,
with a simulated Kitty terminal, the same OpenAI default, and no saved session:
the minimal UI + MCP took a median 0.802 s, and adding plan mode took 0.823 s.
Plan mode therefore added about 21 ms in this check, without startup network
requests or additional runtime dependencies. Automatic network activity remains
enabled; `--offline` is not set globally.

These measure the managed Pi executable directly. The usual outer launcher
uses Bubblewrap, which cannot create namespaces inside the testing environment;
the reported three-second launch in the user's actual Kitty session could not
be reproduced here. No launcher protection was removed or bypassed in its
configuration. Use `PI_TIMING=1 pi` for Pi's internal startup timings locally.
