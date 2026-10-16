# Dotfiles

## Script in `scripts/.local/bin`

Quando crei uno script che ha senso lanciare da solo (non un helper per waybar,
timer o altri script), aggiungilo anche al launcher di fuzzel (Super+Space):

- Crea `scripts/.local/share/applications/script-<nome>.desktop` sul modello
  degli altri: `Name` breve in italiano, `Comment`, `Exec=<nome>`, `Icon` da un
  nome freedesktop generico, `Categories=Utility;`, `Keywords=script;<nome>;`.
- Se lo script richiede argomenti, non mettere gli argomenti nel `.desktop`:
  crea un wrapper `<nome>-menu` che li sceglie con `fuzzel --dmenu` (vedi
  `backup-menu`). Se l'esecuzione è interattiva o lunga, lancia in `kitty`.
- Applica con `stow --restow --target="$HOME" scripts` e verifica con
  `desktop-file-validate`.
