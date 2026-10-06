# dotfiles

Ubuntu + Hyprland workstation configuration.

## Bootstrap

From the repository root:

```sh
./bootstrap
```

`bootstrap` installs the base system, then automatically runs GNU Stow on every
normal top-level directory. Directories whose name starts with `_` are internal
to the repository and are not stowed.

This means adding a new Stow package requires no bootstrap change:

```text
tmux/       -> stowed automatically
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
./_setup/plymouth
./_setup/ros
```

## Convention

```text
_name/   repository infrastructure; never Stow
name/    Stow package
```
