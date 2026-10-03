# dotfiles

Minimal Ubuntu setup.

## Bootstrap

Fresh Ubuntu Server:

    git clone https://github.com/USER/dotfiles.git
    cd dotfiles
    ./bootstrap

## Structure

- `bootstrap` — installs and restores the system
- dotfiles — managed with GNU Stow
- secrets — managed with `pass` + GPG

## Recovery

A complete rebuild requires:

- Ubuntu Server
- this repository
- encrypted backup drive
