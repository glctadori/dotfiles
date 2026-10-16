# dotfiles

Ubuntu + Hyprland workstation configuration.

## Bootstrap

From the repository root:

```sh
./bootstrap
```

`bootstrap` installs the base system, then automatically runs GNU Stow on every
top-level directory tracked by git. Directories whose name starts with `_` are
internal to the repository, and untracked ones (such as `node_modules/`) are never
stowed.

This means adding a new Stow package requires no bootstrap change:

```text
tmux/       -> stowed automatically once committed
_setup/     -> ignored
```

## Layout

- `_setup/` — system installation and machine configuration; not a Stow package
- `scripts/` — commands exposed in `~/.local/bin`
- `systemd/` — user units and timers
- `themes/` — shared desktop themes
- all other top-level directories — GNU Stow packages
- `RECOVERY.md` — recovery notes for a broken system

## Setup stages

`bootstrap` runs:

1. `_setup/base`
2. Stow all dotfile packages
3. `_setup/desktop`
4. `_setup/laptop`
5. `_setup/network`
6. `_setup/fonts`
7. `_setup/dev`
8. `_setup/brave`
9. `_setup/mail`

Optional setup is deliberately separate:

```sh
./_setup/autologin
./_setup/plymouth
./_setup/ros
```

## Claude Code

The `claude` package stows only configuration into `~/.claude`: `settings.json`
and `skills/`. `~/.claude` itself must be a real directory, because Claude Code
keeps credentials, sessions and plugin caches there; `.gitignore` excludes
everything in `claude/.claude/` except the tracked files. Plugins are declared
in `settings.json` and installed by `_setup/dev`. Claude Code runs without sandbox
or managed settings; `settings.json` only denies reading `pass` and gnupg.

## Themes

Each theme in `themes/.config/themes/<name>/` is defined by `palette.toml`
(semantic colors plus the 16 terminal colors) and a `wallpaper.png`. Every other
file is generated: edit the palette, never the outputs.

```sh
theme-build [NAME...]               # regenerate (all themes if none given)
theme-build new NAME [--from THEME] # new theme from an existing palette
theme-build new NAME --kitty FILE   # new theme from a kitty theme .conf
theme NAME                          # apply (Super+F12: theme-menu)
```

Neovim uses the theme's `nvim.lua`. Themes with a dedicated colorscheme plugin
keep a hand-written `nvim.lua` (plugins live in `nvim/.config/nvim/lua/plugins.lua`);
new themes get one generated with `mini.base16` from the palette, regenerated on
every build until it is rewritten by hand.

Browsers: Firefox reads `current/firefox.css` through `userChrome.css`
(`setup-firefox-theme` links the profiles; applies on restart). Brave gets the
palette background as the `BrowserThemeColor` policy, live: `_setup/brave`
installs a root helper that writes only that policy, allowed via sudoers,
because the policy directory must stay root-owned for the web filter.

## Markdown PDF and printing

In Neovim, Markdown and Vimwiki buffers provide:

| Mapping | Command | Action |
| --- | --- | --- |
| `<leader>fp` | `:MarkdownPreview` | Save, generate PDF, open Zathura |
| `<leader>fP` | `:MarkdownPrint` | Save, generate PDF, start `print-duplex` |

Conversion runs asynchronously. `print-duplex` offers page selection and manual
duplex printing through Fuzzel. To load the commands in an existing Neovim
session, run `:lua require('markdown_pdf').setup()`.

The standalone converter accepts `markdown-pdf FILE [OUTPUT]` and prints the
generated PDF's absolute path. Without `OUTPUT`, PDFs are stored under
`~/.cache/markdown-pdf/` (or `$XDG_CACHE_HOME/markdown-pdf/`), separated by source
path. Notes remain unchanged; failed conversions preserve the previous PDF.

```sh
markdown-pdf ~/projects/notes/syllabus-rover-agricolo.md
markdown-pdf ~/projects/notes/syllabus-rover-agricolo.md /tmp/syllabus.pdf
```

PDFs use Pandoc and LuaLaTeX with A4 paper, 11 pt text, 2 cm margins, page
numbers, and no added cover or table of contents. Relative images are resolved
from the note's directory. Dependencies are `pandoc`, `texlive-luatex`,
`texlive-latex-extra`, and Zathura; printing uses the dependencies listed in
`print-duplex`. Run `stow -R scripts nvim` from the repository root to expose
new files through the existing dotfiles layout.

## PDF excerpts

`pdf-compose` extracts and concatenates pages from existing books using Python 3
and `qpdf` (installed by `_setup/printer`). Source books stay in `~/docs/library`;
keep the selection notes and composed PDF in `~/in` for now.

Write a UTF-8 text file such as `~/in/stampa.txt`, with one selection per line:

```text
# Physical PDF pages, counting the first page as 1
make-electronics.pdf | 12-28,35-40
practical-electronics-for-inventors.pdf | 52-65
make-electronics.pdf | 90
```

Numbers refer to physical positions in the PDF, not printed book numbers or PDF
page labels. Ranges include both endpoints. Blank lines and comments beginning
with `#` are ignored. File names may contain spaces. Selections are concatenated
in the written order, including repeated pages; original page sizes are preserved.
No covers, separators, blank pages, or booklet imposition are added.

```sh
pdf-compose ~/in/stampa.txt ~/in/dispensa.pdf --dry-run
pdf-compose ~/in/stampa.txt ~/in/dispensa.pdf
zathura ~/in/dispensa.pdf
print-duplex ~/in/dispensa.pdf
```

The dry run validates sources and ranges and shows the total without writing.
Composition checks the generated PDF and prints its absolute path on stdout;
the selection summary goes to stderr. Existing output files are never overwritten,
and the destination directory must already exist. Password-protected PDFs requiring
a password are rejected.

Relative source paths resolve under `~/docs/libri`; use `--books-dir DIRECTORY`
to change this or write absolute paths in the list. Sources are never modified.
An LLM may optionally reorder the list beforehand using topic comments, preserving
every filename and page selection; the command itself makes no LLM calls.

The command belongs to the existing `scripts` Stow package; on another machine,
run `stow -R scripts` from the dotfiles root to expose it in `~/.local/bin`.


## Embeddings broker

Run `./_setup/setup-agent-secrets` from a normal terminal to install the protected
embeddings broker. Sudo is needed only for setup, updates,
and key rotation; semantic search and indexing need no confirmations.
See [_setup/agent-secrets/README.md](_setup/agent-secrets/README.md) for details and
maintenance commands.

## Convention

```text
_name/   repository infrastructure; never Stow
name/    Stow package
```
