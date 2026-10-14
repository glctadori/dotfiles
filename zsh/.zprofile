export EDITOR="nvim"
export SYSTEMD_EDITOR="nvim"
export VISUAL="nvim"
export BROWSER="brave-browser"
export FZF_DEFAULT_OPTS="--layout=reverse --height 40%"
export LESS="R"
export PATH="$HOME/.local/bin:$PATH"
export SUDO_ASKPASS="$HOME/.local/bin/askpass"
export XDG_DATA_DIRS="$HOME/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share"
# export AGENT="${AGENT:-codex}"

# Avvia Hyprland automaticamente al login su tty1 senza mostrare la console.
if [[ -o interactive && -t 0 && -z $DISPLAY && -z $WAYLAND_DISPLAY && $XDG_VTNR -eq 1 ]]; then
    printf '\e[2J\e[H\e[?25l'
    # Regole schermi della sessione precedente: si riparte col pannello acceso,
    # hypr-hotplug-listener passa all'esterno se è collegato.
    mkdir -p "$HOME/.local/state/hypr" && : > "$HOME/.local/state/hypr/monitors.conf"
    exec start-hyprland > /dev/null 2>&1
fi
