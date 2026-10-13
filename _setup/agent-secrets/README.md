# Agent secret isolation

Codex and Pi share a Bubblewrap launcher. They keep network access and normal
access to the filesystem, while password-store and GPG directories are empty,
read-only mounts. Host processes, runtime control sockets, temporary files,
and host devices are isolated. DNS and the embeddings broker remain reachable.
Desktop control through D-Bus, Wayland, SSH-agent, or host terminal multiplexers
is deliberately unavailable inside these sessions.

## Install

Run from your normal terminal, outside Codex and Pi:

```sh
./_setup/setup-agent-secrets
```

Requires installed Codex, Pi, Bubblewrap, systemd, pass, and sudo. Unlock GPG
first if needed. The setup asks for sudo, imports only the first line of
`api/openrouter`, installs protected service code/configuration, starts a system
socket, and replaces the existing Codex and Pi launcher symlinks. Regular files
at those launcher paths are never overwritten. Restart existing agent sessions.

The managed upstream binaries remain in `~/.codex/packages/standalone/current`
and `~/.pi/agent/bin/pi`, so their managed version updates still work. If an
upstream installer replaces the links in `~/.local/bin`, rerun this setup to
restore the protected launchers. Directly
running those upstream binaries bypasses this isolation; editor integrations
must invoke the `codex` and `pi` launchers on PATH. The Neovim `chat` command uses
`llm` separately and is not an agent entrypoint.

The root-owned copies live in `/usr/local/lib/agent-secrets`; their configuration
is in `/etc/agent-secrets/config.json`. The key is stored root-only in
`/etc/agent-secrets/openrouter` and supplied by systemd `LoadCredential` to a
dedicated dynamic service user. It is never an argument, environment variable,
repository file, or log message. The service cannot read your home or pass store.

## Daily use

```sh
codex
pi
semantic-search wiki "query" --format json
semantic-index library
```

None of these commands needs sudo. Both semantic tools use `agent-embeddings`
instead of `pass`, including when invoked outside an agent. Existing index
databases and output formats are unchanged. No fallback reads pass when the
broker is unavailable.

The socket protocol is a single JSON line with exactly `model` and `input`.
It accepts 1–32 texts and only the existing Perplexity/Qwen embedding models.
The endpoint is fixed to OpenRouter embeddings. Successful responses contain
only numeric `embeddings`; errors contain a sanitized `error`. There is no
credential retrieval, arbitrary URL, custom header, redirect, or shell operation.
The socket checks the configured caller UID. Any process of that user may use
this bounded operation: executable names are not a security boundary when the
user/agent can edit the client scripts. API requests consume normal API credit.

## Updates and checks

```sh
# Update protected service/launcher code without rereading pass:
./_setup/setup-agent-secrets
# After changing api/openrouter in pass:
./_setup/setup-agent-secrets --rotate-key
# Check isolation without making a paid API call:
/usr/bin/python3 -I /usr/local/lib/agent-secrets/launch.py check
# Inspect service status (never includes the key):
systemctl status agent-embeddings.socket agent-embeddings.service
# Unit, isolation integration, and compatibility tests with a fake key/API:
python3 -B _setup/agent-secrets/test_broker.py
```

Change authorized embedding models/endpoints in the broker source, review the
change, then rerun setup with sudo. Editing semantic-search/index does not need
sudo. This installation is intentionally explicit rather than importing secrets
automatically during bootstrap. On an existing machine run it before restowing
the scripts package, to replace conflicting upstream launcher symlinks.

If setup fails, fix the reported problem and rerun it; launchers never fall back
to an unsandboxed agent. To remove the setup deliberately from a trusted terminal,
disable its system socket/service and restore the upstream launcher symlinks.

## Boundary

Protection applies to sessions started through these launchers, the configured
password-store/GPG directories and their resolved symlinks, and the broker key.
It does not cover copies of secrets elsewhere, credentials in model-provider
configuration, arbitrary host services reachable over the network, or changes
to user files subsequently executed outside the sandbox. Broad file access
allows persistent edits; review them before running them outside the sandbox.
Do not grant agents general sudo or an unrestricted host execution channel.

Claude Code does not use this launcher: it relies on its own sandbox and deny rules
(see `_setup/claude-code/`). D-Bus, Wayland and SSH-agent are unavailable inside Codex and Pi.
