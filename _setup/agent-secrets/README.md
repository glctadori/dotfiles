# Embeddings broker

Il broker tiene la chiave OpenRouter fuori dai processi dell'utente: `semantic-search`
e `semantic-index` chiedono gli embeddings tramite `agent-embeddings` invece di leggere
`pass`. Codex, Pi e Claude Code non usano sandbox; Claude Code ha solo i deny su pass e
gnupg nelle managed settings (vedi `_setup/claude-code/`).

## Install

Dal terminale normale:

```sh
./_setup/setup-agent-secrets
```

Requires systemd, pass, and sudo. Unlock GPG first if needed. The setup asks for
sudo, imports only the first line of `api/openrouter`, installs protected service
code/configuration, starts a system socket, and links `agent-embeddings` in
`~/.local/bin`.

The root-owned copy lives in `/usr/local/lib/agent-secrets`; its configuration
is in `/etc/agent-secrets/config.json`. The key is stored root-only in
`/etc/agent-secrets/openrouter` and supplied by systemd `LoadCredential` to a
dedicated dynamic service user. It is never an argument, environment variable,
repository file, or log message. The service cannot read your home or pass store.

## Daily use

```sh
semantic-search wiki "query" --format json
semantic-index library
```

None of these commands needs sudo. Both semantic tools use `agent-embeddings`
instead of `pass`. Existing index
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
# Update protected service code without rereading pass:
./_setup/setup-agent-secrets
# After changing api/openrouter in pass:
./_setup/setup-agent-secrets --rotate-key
# Inspect service status (never includes the key):
systemctl status agent-embeddings.socket agent-embeddings.service
# Unit and compatibility tests with a fake key/API:
python3 -B _setup/agent-secrets/test_broker.py
```

Change authorized embedding models/endpoints in the broker source, review the
change, then rerun setup with sudo. Editing semantic-search/index does not need
sudo. This installation is intentionally explicit rather than importing secrets
automatically during bootstrap.

If setup fails, fix the reported problem and rerun it. To remove the setup, disable
`agent-embeddings.socket`/`.service` and delete `/usr/local/lib/agent-secrets` and
`/etc/agent-secrets`.

## Boundary

The socket checks the configured caller UID, so the key is protected from other
users and from reading the file, not from any process of the same user.
