# ── Line editing ────────────────────────────────────────────────

# Shell semplice: Neovim gestisce l'editing modale
bindkey -e

# Ctrl-E: modifica il comando corrente in Neovim
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^E' edit-command-line

# Incolla URL senza doverli quotare
autoload -Uz url-quote-magic
zle -N self-insert url-quote-magic


# ── Completion ──────────────────────────────────────────────────

autoload -Uz compinit
compinit

zstyle ':completion:*' menu select
zmodload zsh/complist


# ── Prompt ──────────────────────────────────────────────────────

# Fallback: Starship lo sostituisce quando disponibile
autoload -U colors && colors
PS1='%B%F{blue}%~%f %(!.#.>) %b'


# ── History ─────────────────────────────────────────────────────

HISTFILE=~/.cache/zsh/history
HISTSIZE=100000
SAVEHIST=100000

mkdir -p "${HISTFILE:h}"

setopt appendhistory
setopt sharehistory


# ── Shell options ───────────────────────────────────────────────

setopt autocd
setopt interactivecomments


# ── Aliases ─────────────────────────────────────────────────────

alias vim='nvim'
alias vimdiff='nvim -d'
alias v='nvim'
alias e='$EDITOR'
alias sw='stow -vt $HOME'
alias cq='source ~/projects/cad/.venv/bin/activate'
alias ros='source /opt/ros/lyrical/setup.zsh'

alias cp='cp -iv'
alias mv='mv -iv'

# Safe delete
alias rm='trash-put'

# Permanent delete
alias rrm='/usr/bin/rm -I'

alias mkd='mkdir -pv'

alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias ip='ip -color=auto'

alias g='git'
alias p='sudo pacman'
alias za='zathura'
alias c='codex'

alias cad='cd ~/projects/cad'

if (( $+commands[eza] )); then
    alias ls='eza --group-directories-first --icons=auto'
    alias ll='eza --long --group --header --git --group-directories-first --icons=auto'
    alias la='eza --long --group --header --git --all --group-directories-first --icons=auto'
    alias tree='eza --tree --group-directories-first --icons=auto'
else
    alias ls='ls -hN --color=auto --group-directories-first'
    alias ll='ls -lhN --color=auto --group-directories-first'
    alias la='ls -lahN --color=auto --group-directories-first'
fi

(( $+commands[bat] )) && alias b='bat'

# ── Git pager ───────────────────────────────────────────────────

if (( $+commands[delta] )); then
    export GIT_PAGER='delta'
    export DELTA_PAGER='less -FRX'
fi


# ── fzf ─────────────────────────────────────────────────────────

export FZF_DEFAULT_OPTS="
    --height=70%
    --min-height=20
    --layout=reverse
    --border=rounded
    --info=inline-right
    --prompt='❯ '
    --pointer='›'
    --marker='✓'
    --scrollbar='▐'
    --cycle
    --bind='ctrl-/:toggle-preview'
    --preview-window='right,60%,border-left'
    $(cat "${XDG_CONFIG_HOME:-$HOME/.config}/themes/current/fzf")
"

unset FZF_DEFAULT_OPTS_FILE

export FZF_CTRL_T_COMMAND="fd --hidden --follow --exclude .git --exclude node_modules --strip-cwd-prefix"
export FZF_ALT_C_COMMAND="fd --type d --hidden --follow --exclude .git --exclude node_modules --strip-cwd-prefix"

export FZF_CTRL_T_OPTS="--preview='/usr/share/fzf/fzf-preview.sh {}' --header='Invio: inserisci  ·  Tab: seleziona  ·  Ctrl-/: anteprima'"
export FZF_ALT_C_OPTS="--header='Invio: entra nella directory'"

# fzf shell integration
source <(fzf --zsh)


# ── yt-dlp ──────────────────────────────────────────────────────

yt() {
    yt-dlp \
        -f 'bv*[height<=1080]+ba/b[height<=1080]' \
        --merge-output-format mp4 \
        -P "$(xdg-user-dir DOWNLOAD)" \
        --no-playlist \
        "$@"
}

yta() {
    yt-dlp \
        -f 'ba/b' \
        -x \
        -P "$(xdg-user-dir DOWNLOAD)" \
        --no-playlist \
        "$@"
}

ytp() {
    yt-dlp \
        -f 'bv*[height<=1080]+ba/b[height<=1080]' \
        --merge-output-format mp4 \
        -P "$(xdg-user-dir DOWNLOAD)" \
        -o '%(playlist_title)s/%(playlist_index)03d - %(title)s.%(ext)s' \
        --yes-playlist \
        "$@"
}


# ── Projects / files ────────────────────────────────────────────

alias cadnew='project-create cadquery'

fe() {
    local root=${1:-.}
    local selected file
    local -a files

    [[ -d $root ]] || {
        print -u2 "fe: directory inesistente: $root"
        return 1
    }

    root=${root:A}

    selected=$(
        cd -- "$root" &&
            fd --type f --hidden --follow \
                --exclude .git \
                --exclude node_modules \
                --print0 |
            fzf --read0 --print0 --multi \
                --prompt='file ❯ ' \
                --preview='/usr/share/fzf/fzf-preview.sh {}' \
                --header='Invio: apri  ·  Tab: seleziona  ·  Ctrl-/: anteprima'
    ) || return

    for file in ${(0)selected}; do
        [[ -n $file ]] && files+=("$root/$file")
    done

    (( ${#files} )) && ${EDITOR:-nvim} -- "${files[@]}"
}

se() {
    fe "$HOME/projects/dotfiles"
}

pj() {
    local root="$HOME/projects"
    local selected project
    local -a projects

    selected=$(
        cd -- "$root" &&
            fd --type d \
                --min-depth 1 \
                --max-depth 2 \
                --hidden \
                --exclude .git \
                --exclude node_modules \
                --print0 |
            fzf --read0 --print0 \
                --prompt='progetto ❯ ' \
                --header='Invio: entra nel progetto'
    ) || return

    projects=("${(@0)selected}")
    project=$projects[1]

    [[ -n "$project" ]] && cd "$root/$project"
}


# ── Git helpers ─────────────────────────────────────────────────

gbr() {
    git rev-parse --git-dir >/dev/null 2>&1 || {
        print -u2 'gbr: non sei in un repository Git'
        return 1
    }

    local branch

    branch=$(
        git for-each-ref \
            --format='%(refname:short)' \
            refs/heads |
            fzf \
                --prompt='branch ❯ ' \
                --header='Invio: git switch  ·  Ctrl-/: anteprima' \
                --preview='git log --color=always --graph --date=short --pretty=format:"%C(auto)%h%d %s %C(black)%C(bold)%cr" --max-count=30 {}'
    ) || return

    [[ -n $branch ]] && git switch -- "$branch"
}

gshow() {
    git rev-parse --git-dir >/dev/null 2>&1 || {
        print -u2 'gshow: non sei in un repository Git'
        return 1
    }

    local selected hash

    selected=$(
        git log --color=always --date=short \
            --pretty=format:'%h%x09%C(auto)%h%d %s %C(black)%C(bold)%cr' |
            fzf \
                --ansi \
                --delimiter=$'\t' \
                --with-nth=2.. \
                --prompt='commit ❯ ' \
                --header='Invio: git show  ·  Ctrl-/: anteprima' \
                --preview='git show --color=always --stat --patch {1}'
    ) || return

    hash=${selected%%$'\t'*}

    [[ -n $hash ]] &&
        git show --color=always "$hash"
}


# ── Calculator ──────────────────────────────────────────────────

# Ctrl-A → bc
bindkey -s '^A' '^Ubc -lq\n'


# ── Prompt / navigation ─────────────────────────────────────────

(( $+commands[zoxide] )) &&
    eval "$(zoxide init zsh --cmd z)"

(( $+commands[starship] )) &&
    eval "$(starship init zsh)"

# Fdfind
if (( $+commands[fd] )); then
    FD=fd
elif (( $+commands[fdfind] )); then
    FD=fdfind
fi

export FZF_CTRL_T_COMMAND="$FD --hidden --follow --exclude .git --exclude node_modules --strip-cwd-prefix"
export FZF_ALT_C_COMMAND="$FD --type d --hidden --follow --exclude .git --exclude node_modules --strip-cwd-prefix"


# ── PATH ────────────────────────────────────────────────────────

export PATH="$HOME/.local/bin:$PATH"


# ── Syntax highlighting ─────────────────────────────────────────
# Deve stare alla fine.

source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
