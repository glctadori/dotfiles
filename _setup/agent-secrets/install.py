#!/usr/bin/python3
"""Root installation step. Read credential from stdin only when requested."""

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def write_owned(path, content, mode):
    path.write_text(content)
    path.chmod(mode)
    os.chown(path, 0, 0)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--uid", type=int, required=True)
    parser.add_argument("--gid", type=int, required=True)
    parser.add_argument("--credential", action="store_true")
    args = parser.parse_args()
    if os.geteuid() != 0 or args.uid == 0:
        raise SystemExit("installer requires sudo and a non-root user")
    source = Path(__file__).resolve().parent
    library = Path("/usr/local/lib/agent-secrets")
    config_dir = Path("/etc/agent-secrets")
    for directory in (library, config_dir):
        directory.mkdir(mode=0o755, parents=True, exist_ok=True)
        os.chown(directory, 0, 0)
        directory.chmod(0o755)
    write_owned(library / "service.py", (source / "service.py").read_text(), 0o644)
    if args.credential:
        key = sys.stdin.buffer.read(16385).strip()
        if not key or len(key) > 16384 or b"\n" in key or b"\r" in key:
            raise SystemExit("invalid credential on installer stdin")
        descriptor, temporary = tempfile.mkstemp(dir=config_dir, prefix=".credential-")
        try:
            with os.fdopen(descriptor, "wb") as output:
                output.write(key)
            os.chmod(temporary, 0o600)
            os.replace(temporary, config_dir / "openrouter")
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
    if not (config_dir / "openrouter").is_file():
        raise SystemExit("no service credential; rerun setup with --rotate-key")
    config = {"uid": args.uid, "gid": args.gid}
    write_owned(config_dir / "config.json", json.dumps(config, indent=2) + "\n", 0o644)
    write_owned(Path("/etc/systemd/system/agent-embeddings.socket"), f"""[Unit]
Description=Agent embeddings credential broker socket

[Socket]
ListenStream=/run/agent-embeddings/socket
SocketUser=root
SocketGroup={args.gid}
SocketMode=0660
DirectoryMode=0755
RemoveOnStop=yes

[Install]
WantedBy=sockets.target
""", 0o644)
    write_owned(Path("/etc/systemd/system/agent-embeddings.service"), """[Unit]
Description=Agent embeddings credential broker
Requires=agent-embeddings.socket
After=agent-embeddings.socket

[Service]
Type=simple
DynamicUser=yes
ExecStart=/usr/bin/python3 -I /usr/local/lib/agent-secrets/service.py
LoadCredential=openrouter:/etc/agent-secrets/openrouter
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
PrivateDevices=yes
ProtectProc=invisible
ProcSubset=pid
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictSUIDSGID=yes
RestrictNamespaces=yes
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
CapabilityBoundingSet=
UMask=0077
LimitCORE=0
MemoryMax=512M
TasksMax=16
Restart=on-failure
RestartSec=2
""", 0o644)
    subprocess.run(["systemctl", "daemon-reload"], check=True)
    subprocess.run(["systemctl", "enable", "--now", "agent-embeddings.socket"], check=True)
    subprocess.run(["systemctl", "restart", "agent-embeddings.service"], check=True)
    print("Protected embeddings service installed.")


if __name__ == "__main__":
    main()
