"""Paste: se la clipboard contiene un'immagine manda Ctrl+V all'app, altrimenti incolla il testo."""

import subprocess

from kittens.tui.handler import result_handler


def clipboard_has_image():
    try:
        out = subprocess.run(
            ["wl-paste", "-l"], capture_output=True, text=True, timeout=1
        ).stdout
    except (OSError, subprocess.SubprocessError):
        return False
    return any(line.startswith("image/") for line in out.splitlines())


def main(args):
    pass


@result_handler(no_ui=True)
def handle_result(args, answer, target_window_id, boss):
    window = boss.window_id_map.get(target_window_id)
    if window is None:
        return
    if clipboard_has_image():
        window.write_to_child(b"\x16")
    else:
        boss.paste_from_clipboard()
