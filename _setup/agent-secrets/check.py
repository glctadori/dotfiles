#!/usr/bin/python3
"""Run inside the launcher. Report access checks, never file contents."""

import json
import os
from pathlib import Path
import socket
import sys


def main():
    config = json.loads(Path("/etc/agent-secrets/config.json").read_text())
    failures = []
    for path in config["secret_paths"]:
        try:
            if list(Path(path).iterdir()):
                failures.append("secret directory is visible")
        except FileNotFoundError:
            pass
        if Path(path).exists() and os.access(path, os.W_OK):
            failures.append("secret directory is writable")
    for path in ("/run/dbus/system_bus_socket", f"/run/user/{config['uid']}/bus",
                 f"/run/user/{config['uid']}/systemd/private",
                 f"/run/user/{config['uid']}/gnupg"):
        if Path(path).exists():
            failures.append("host control socket is visible")
    for path in ("/etc/agent-secrets/openrouter", "/proc/1/root/etc/agent-secrets/openrouter"):
        try:
            descriptor = os.open(path, os.O_RDONLY)
        except OSError:
            continue
        os.close(descriptor)
        failures.append("service credential is readable")
    for path in ("/usr/local/lib/agent-secrets/service.py", "/etc/agent-secrets/config.json"):
        if os.access(path, os.W_OK):
            failures.append("protected service configuration is writable")
    if len([p for p in Path("/proc").iterdir() if p.name.isdigit()]) > 5:
        failures.append("host processes may be visible")
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
            connection.settimeout(10)
            connection.connect("/run/agent-embeddings/socket")
            connection.sendall(b'{"model":"forbidden","input":["probe"]}\n')
            with connection.makefile("rb") as stream:
                result = json.loads(stream.readline(4096))
        if result != {"error": "model is not allowed"}:
            failures.append("broker validation failed")
    except (OSError, ValueError):
        failures.append("embedding service is unavailable")
    if failures:
        for failure in failures:
            print("FAIL: " + failure)
        return 1
    print("OK: secret directories and host sockets hidden; credential and service protected; broker reachable")
    return 0


if __name__ == "__main__":
    sys.exit(main())
