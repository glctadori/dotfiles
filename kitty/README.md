# Kitty copy mode

`Super+Y` or `Ctrl+Shift+H` opens Neovim in an overlay. Use `hjkl`, `gg` / `G`,
`/` to search, `v` / `V` to select, and `y` / `yy` to copy to the system clipboard.
Press `q` to close the overlay and return to the underlying program.

The viewer uses the current theme from `~/.config/themes/current/nvim.lua`
and its installed color scheme, with a dedicated minimal config without editor plugins, session history,
swap files, or writes to the original content. Its temporary text copy is
private and deleted when Neovim exits.

In Pi, the minimal UI extension publishes the saved session path and active
branch ID through a Kitty user variable. Copy mode follows that branch and
includes user/assistant text outside the visible fullscreen viewport, with
original Markdown and LaTeX. Tool output and hidden reasoning are excluded.
It uses completed saved messages; an unsaved or ephemeral session falls back
to the visible screen. Other programs use Kitty's plain screen and scrollback.

Reload Kitty config with `Ctrl+Shift+F5`, and `/reload` in Pi to activate the
session metadata integration. Stow links all three files in `.config/kitty`.

Run the regression checks from the dotfiles root:

```sh
kitty +runpy 'import runpy; runpy.run_path("kitty/tests/test_copy_mode.py", run_name="__main__")'
```
