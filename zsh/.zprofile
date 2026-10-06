export EDITOR="nvim"
export SYSTEMD_EDITOR="nvim"
export VISUAL="nvim"
export BROWSER="brave"
export FZF_DEFAULT_OPTS="--layout=reverse --height 40%"
export LESS="R"
export PATH="$HOME/.local/bin:$PATH"
export SUDO_ASKPASS="$HOME/.local/bin/askpass"
export XDG_DATA_DIRS="$HOME/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share"
# export AGENT="${AGENT:-codex}"

# Avvia Hyprland automaticamente al login su tty1 senza mostrare la console.
if [[ -z $DISPLAY && $XDG_VTNR -eq 1 ]]; then
    printf '\e[2J\e[H\e[?25l'
    exec start-hyprland > /dev/null 2>&1
fi
