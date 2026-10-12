#!/usr/bin/python3
"""Credential broker: a bounded embeddings operation, never arbitrary HTTP."""

import json
import math
import os
from pathlib import Path
import socket
import struct
import urllib.error
import urllib.request

API_URL = "https://openrouter.ai/api/v1/embeddings"
MODELS = frozenset(("perplexity/pplx-embed-v1-0.6b", "qwen/qwen3-embedding-8b"))
MAX_REQUEST = 2 * 1024 * 1024
MAX_RESPONSE = 32 * 1024 * 1024


class BrokerError(Exception):
    pass


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise BrokerError("upstream redirects are not allowed")


def validate_request(payload):
    if not isinstance(payload, dict) or set(payload) != {"model", "input"}:
        raise BrokerError("only model and input are accepted")
    model, texts = payload["model"], payload["input"]
    if not isinstance(model, str) or model not in MODELS:
        raise BrokerError("model is not allowed")
    if (not isinstance(texts, list) or not 1 <= len(texts) <= 32
            or any(not isinstance(t, str) or not t.strip() or len(t) > 64000
                   for t in texts)):
        raise BrokerError("input must contain 1-32 nonempty texts, at most 64000 characters each")
    return model, texts


def validate_response(payload, count):
    try:
        data = payload["data"]
        if not isinstance(data, list) or len(data) != count:
            raise ValueError
        vectors = [None] * count
        for item in data:
            index, vector = item["index"], item["embedding"]
            if (type(index) is not int or not 0 <= index < count
                    or vectors[index] is not None or not isinstance(vector, list)
                    or not 1 <= len(vector) <= 65536
                    or any(type(v) not in (int, float) or not math.isfinite(v) for v in vector)):
                raise ValueError
            vectors[index] = vector
        if len({len(v) for v in vectors}) != 1:
            raise ValueError
        return vectors
    except (KeyError, TypeError, ValueError, OverflowError):
        raise BrokerError("invalid embedding response") from None


def embeddings(payload, key):
    model, texts = validate_request(payload)
    request = urllib.request.Request(
        API_URL,
        data=json.dumps({"model": model, "input": texts}).encode(),
        headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"},
        method="POST",
    )
    # Ignore proxy environment variables and never forward credentials to a redirect.
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
    try:
        with opener.open(request, timeout=120) as response:
            raw = response.read(MAX_RESPONSE + 1)
        if len(raw) > MAX_RESPONSE:
            raise BrokerError("embedding response is too large")
        vectors = validate_response(json.loads(raw), len(texts))
    except urllib.error.HTTPError as exc:
        raise BrokerError(f"embedding API returned HTTP {exc.code}") from None
    except (urllib.error.URLError, OSError, ValueError):
        raise BrokerError("embedding API request failed") from None
    return {"embeddings": vectors}


def handle_connection(connection, allowed_uid, key):
    connection.settimeout(150)
    try:
        uid = struct.unpack("3i", connection.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, 12))[1]
        if uid != allowed_uid:
            raise BrokerError("caller is not authorized")
        with connection.makefile("rb") as stream:
            raw = stream.readline(MAX_REQUEST + 1)
        if len(raw) > MAX_REQUEST or not raw.endswith(b"\n"):
            raise BrokerError("request is too large or incomplete")
        try:
            payload = json.loads(raw)
        except (ValueError, UnicodeError):
            raise BrokerError("invalid JSON request") from None
        result = embeddings(payload, key)
    except BrokerError as exc:
        result = {"error": str(exc)}
    except Exception:
        # Never include exception text, upstream bodies, headers, or tracebacks.
        result = {"error": "embedding service failed"}
    try:
        connection.sendall(json.dumps(result, allow_nan=False).encode() + b"\n")
    except OSError:
        pass


def main():
    config = json.loads(Path("/etc/agent-secrets/config.json").read_text())
    credential = Path(os.environ["CREDENTIALS_DIRECTORY"]) / "openrouter"
    key = credential.read_text().strip()
    if not key or "\n" in key or "\r" in key:
        raise SystemExit("invalid OpenRouter credential")
    if os.environ.get("LISTEN_PID") != str(os.getpid()) or os.environ.get("LISTEN_FDS") != "1":
        raise SystemExit("service must be started by its systemd socket")
    listener = socket.socket(fileno=3)
    while True:
        connection, _ = listener.accept()
        with connection:
            handle_connection(connection, config["uid"], key)


if __name__ == "__main__":
    main()
