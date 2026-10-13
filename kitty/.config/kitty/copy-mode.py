"""Open terminal text, or Pi's active conversation, in a Neovim overlay."""

import json
import os
import tempfile
from pathlib import Path

from kittens.tui.handler import result_handler
from kitty.constants import config_dir


def message_text(message):
    content = message.get("content", "")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "\n".join(
            block["text"] for block in content
            if isinstance(block, dict) and block.get("type") == "text"
            and isinstance(block.get("text"), str)
        )
    return ""


def pi_transcript(metadata):
    """Follow parent IDs so abandoned branches and tool output are not copied."""
    try:
        source = json.loads(metadata)
        filename, leaf = source.get("file"), source.get("leaf")
        if not isinstance(filename, str) or not isinstance(leaf, str):
            return None
        if not Path(filename).is_absolute():
            return None
        entries = {}
        has_header = False
        with open(filename, encoding="utf-8") as stream:
            for line in stream:
                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    continue  # The final JSONL record can still be getting written.
                if not isinstance(entry, dict):
                    continue
                if entry.get("type") == "session":
                    has_header = True
                    continue
                entry_id = entry.get("id")
                if not isinstance(entry_id, str):
                    continue
                text = ""
                message = entry.get("message")
                if entry.get("type") == "message" and isinstance(message, dict):
                    role = message.get("role")
                    if role in ("user", "assistant"):
                        body = message_text(message).strip()
                        if body:
                            text = f"## {'Tu' if role == 'user' else 'Pi'}\n\n{body}"
                entries[entry_id] = (entry.get("parentId"), text)
        if not has_header or leaf not in entries:
            return None
        blocks, seen = [], set()
        while isinstance(leaf, str) and leaf in entries and leaf not in seen:
            seen.add(leaf)
            leaf, text = entries[leaf]
            if text:
                blocks.append(text)
        return "# Conversazione Pi\n\n" + "\n\n".join(reversed(blocks)) + "\n"
    except (OSError, ValueError, AttributeError):
        return None


def main(args):
    pass  # no_ui: the handler runs in Kitty, without starting an extra terminal UI.


@result_handler(no_ui=True)
def handle_result(args, answer, target_window_id, boss):
    window = boss.window_id_map.get(target_window_id)
    if window is None:
        return
    metadata = window.user_vars.get("pi_copy_session")
    text = pi_transcript(metadata) if metadata else None
    from_pi = text is not None
    if text is None:
        text = window.as_text(as_ansi=False, add_history=True)
    cache = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "kitty-copy-mode"
    cache.mkdir(mode=0o700, parents=True, exist_ok=True)
    descriptor, filename = tempfile.mkstemp(prefix="view-", suffix=".md", dir=cache)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            stream.write(text)
        title = "Copy mode · Pi" if from_pi else "Copy mode · terminale"
        boss.call_remote_control(window, (
            "launch", "--type=overlay", "--source-window", f"id:{target_window_id}",
            "--title", title, "--env", f"KITTY_COPY_FILE={filename}",
            "nvim", "--noplugin", "-i", "NONE", "-u",
            # Kitty runs kittens without __file__, so locate the viewer config explicitly.
            str(Path(config_dir) / "copy-mode.lua"), filename,
        ))
    except Exception:
        Path(filename).unlink(missing_ok=True)
        raise
