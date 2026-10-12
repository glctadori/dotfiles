#!/usr/bin/python3
"""Shared entrypoint for agents; installed as a root-owned copy."""

import json
import os
from pathlib import Path
import resource
import sys

CONFIG = Path("/etc/agent-secrets/config.json")


def build_command(config, mode, arguments, environ):
    home = Path(config["home"])
    if os.getuid() != config["uid"] or mode not in ("codex", "pi", "check"):
        raise ValueError("agent launcher is not configured for this user or command")
    if mode == "codex":
        program = [str(home / ".codex/packages/standalone/current/bin/codex"),
                   "--no-daemon", "--ask-for-approval", "never", "--sandbox", "danger-full-access"]
    elif mode == "pi":
        program = [str(home / ".pi/agent/bin/pi")]
    else:
        program = ["/usr/bin/python3", "-I", "/usr/local/lib/agent-secrets/check.py"]
    if not Path(program[0]).is_file() or not os.access(program[0], os.X_OK):
        raise ValueError("agent executable is missing; install Codex or Pi first")

    # Include both configured paths and runtime overrides, resolving symlinks before masking.
    paths = set(config["secret_paths"])
    paths.update((str(home / ".password-store"), str(home / ".gnupg")))
    for name in ("PASSWORD_STORE_DIR", "GNUPGHOME"):
        if environ.get(name):
            paths.add(environ[name])
    protected = {str(Path(p).resolve()) for p in paths}
    for path in protected:
        if path in ("/", str(home), "/run", "/tmp", "/usr", "/etc"):
            raise ValueError("secret path overlaps an essential directory")
        if Path(path).exists() and not Path(path).is_dir():
            raise ValueError("secret paths must be directories")
        if Path(os.getcwd()).is_relative_to(path):
            raise ValueError("cannot start an agent inside a secret directory")

    command = ["/usr/bin/bwrap", "--unshare-user", "--unshare-pid", "--unshare-ipc",
               "--unshare-uts", "--cap-drop", "ALL", "--new-session", "--die-with-parent",
               "--bind", "/", "/", "--ro-bind", "/sys", "/sys",
               "--proc", "/proc", "--dev", "/dev", "--tmpfs", "/tmp", "--tmpfs", "/run"]
    # Keep DNS and the single credential broker; do not expose host control sockets.
    if Path("/run/systemd/resolve").is_dir():
        command += ["--ro-bind", "/run/systemd/resolve", "/run/systemd/resolve"]
    if not Path("/run/agent-embeddings/socket").is_socket():
        raise ValueError("embedding socket is missing; start agent-embeddings.socket")
    command += ["--ro-bind", "/run/agent-embeddings", "/run/agent-embeddings"]
    runtime = f"/run/user/{config['uid']}"
    command += ["--dir", runtime, "--setenv", "XDG_RUNTIME_DIR", runtime]
    for path in sorted(protected, key=lambda p: (p.count("/"), p)):
        if Path(path).exists():
            command += ["--tmpfs", path, "--remount-ro", path]
    # Do not let inherited variables carry API keys or host socket/IPC locations.
    for name in environ:
        upper = name.upper()
        if (upper.endswith(("_API_KEY", "_API_TOKEN", "_SECRET", "_PASSWORD", "_ACCESS_TOKEN"))
                or name in ("GPG_AGENT_INFO", "SSH_AUTH_SOCK", "DBUS_SESSION_BUS_ADDRESS",
                            "DBUS_SYSTEM_BUS_ADDRESS", "DISPLAY", "WAYLAND_DISPLAY",
                            "TMUX", "STY", "CREDENTIALS_DIRECTORY", "LISTEN_FDS", "LISTEN_PID")):
            command += ["--unsetenv", name]
    command += ["--", *program, *arguments]
    return command


def main():
    try:
        config = json.loads(CONFIG.read_text())
        mode = sys.argv[1] if len(sys.argv) > 1 else ""
        command = build_command(config, mode, sys.argv[2:], os.environ)
    except (OSError, ValueError, KeyError) as exc:
        raise SystemExit(f"error: {exc}; configure with _setup/setup-agent-secrets outside the agent") from None
    # No inherited directory or socket descriptors that could cross the boundary.
    maximum = resource.getrlimit(resource.RLIMIT_NOFILE)[0]
    if maximum == resource.RLIM_INFINITY:
        maximum = 1048576
    os.closerange(3, min(maximum, 1048576))
    os.execv(command[0], command)


if __name__ == "__main__":
    main()
