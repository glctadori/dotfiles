#!/usr/bin/python3
"""Security boundaries and semantic index compatibility using fake credentials."""

import contextlib
import importlib.machinery
import importlib.util
import io
import json
import os
from pathlib import Path
import socket
import sqlite3
import subprocess
import tempfile
import threading
import unittest
from unittest.mock import patch
import urllib.error

ROOT = Path(__file__).resolve().parents[2]


def load(name, path):
    loader = importlib.machinery.SourceFileLoader(name, str(path))
    spec = importlib.util.spec_from_loader(name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


broker = load("broker", ROOT / "_setup/agent-secrets/service.py")
index = load("semantic_index", ROOT / "scripts/.local/bin/semantic-index")
search = load("semantic_search", ROOT / "scripts/.local/bin/semantic-search")
client = load("embedding_client", ROOT / "scripts/.local/bin/agent-embeddings")
MODEL = "perplexity/pplx-embed-v1-0.6b"
KEY = "fake-credential-never-return-this"


class BrokerTests(unittest.TestCase):
    def test_rejects_arbitrary_capabilities(self):
        for payload in (
            {"model": MODEL, "input": ["test"], "url": "http://elsewhere"},
            {"model": MODEL, "input": ["test"], "headers": {"X": "Y"}},
            {"model": "chat-model", "input": ["test"]},
            {"model": [], "input": ["test"]},
            {"model": MODEL, "input": []},
            {"model": MODEL, "input": ["test"] * 33},
            {"model": MODEL, "input": [" "]},
            {"model": MODEL, "input": ["x" * 64001]},
            {"model": MODEL, "input": [42]},
        ):
            with self.subTest(payload_type=type(payload)):
                with patch.object(broker.urllib.request, "build_opener") as opener:
                    with self.assertRaises(broker.BrokerError):
                        broker.embeddings(payload, KEY)
                    opener.assert_not_called()

    def test_only_numeric_vectors_are_returned_in_input_order(self):
        upstream = {"data": [{"index": 1, "embedding": [0.0, 1.0]},
                             {"index": 0, "embedding": [1.0, 0.0]}],
                    "secret": KEY, "other": "provider metadata"}
        response = io.BytesIO(json.dumps(upstream).encode())
        with patch.object(broker.urllib.request, "build_opener") as factory:
            factory.return_value.open.return_value = response
            result = broker.embeddings({"model": MODEL, "input": ["one", "two"]}, KEY)
            request = factory.return_value.open.call_args.args[0]
        self.assertEqual(request.full_url, broker.API_URL)
        self.assertEqual(request.get_header("Authorization"), "Bearer " + KEY)
        self.assertEqual(result, {"embeddings": [[1.0, 0.0], [0.0, 1.0]]})
        self.assertNotIn(KEY, json.dumps(result))

    def test_invalid_upstream_vectors(self):
        for vector in ([KEY], [float("nan")], [float("inf")], [True], []):
            with self.assertRaises(broker.BrokerError):
                broker.validate_response({"data": [{"index": 0, "embedding": vector}]}, 1)
        with self.assertRaises(broker.BrokerError):
            broker.validate_response({"data": [{"index": 0, "embedding": [1]},
                                                {"index": 0, "embedding": [1]}]}, 2)

    def test_provider_error_body_and_exception_are_not_returned(self):
        error = urllib.error.HTTPError(broker.API_URL, 401, KEY, {}, io.BytesIO(KEY.encode()))
        with patch.object(broker.urllib.request, "build_opener") as factory:
            factory.return_value.open.side_effect = error
            with self.assertRaisesRegex(broker.BrokerError, "HTTP 401") as caught:
                broker.embeddings({"model": MODEL, "input": ["one"]}, KEY)
        self.assertNotIn(KEY, str(caught.exception))

    def test_redirects_cannot_forward_the_key(self):
        with self.assertRaises(broker.BrokerError):
            broker.NoRedirect().redirect_request(None, None, 302, KEY, {}, "https://elsewhere")

    def roundtrip(self, request, uid=None, operation=None):
        local, remote = socket.socketpair()
        with local, remote:
            local.settimeout(5)
            with patch.object(broker, "embeddings", operation or broker.embeddings):
                thread = threading.Thread(target=broker.handle_connection,
                                          args=(remote, os.getuid() if uid is None else uid, KEY))
                thread.start()
                local.sendall(request)
                local.shutdown(socket.SHUT_WR)
                with local.makefile("rb") as stream:
                    response = json.loads(stream.readline(broker.MAX_RESPONSE))
                thread.join(5)
                self.assertFalse(thread.is_alive())
                return response

    def test_socket_rejects_wrong_uid_and_malformed_requests(self):
        self.assertEqual(self.roundtrip(b"{}\n", uid=os.getuid() + 1),
                         {"error": "caller is not authorized"})
        self.assertEqual(self.roundtrip(b"not-json\n"), {"error": "invalid JSON request"})
        self.assertEqual(self.roundtrip(b"{}"), {"error": "request is too large or incomplete"})
        with patch.object(broker, "MAX_REQUEST", 16):
            self.assertEqual(self.roundtrip(b"x" * 17 + b"\n"),
                             {"error": "request is too large or incomplete"})

    def test_socket_sanitizes_unexpected_exceptions(self):
        def failure(payload, key):
            raise RuntimeError(KEY)
        result = self.roundtrip(b'{"model":"test","input":["test"]}\n', operation=failure)
        self.assertEqual(result, {"error": "embedding service failed"})

    def test_client_reports_unavailable_service_without_pass(self):
        with tempfile.TemporaryDirectory() as temporary:
            stdin = type("Input", (), {"buffer": io.BytesIO(b'{"model":"test","input":["test"]}')})()
            with patch.object(client, "SOCKET", temporary + "/missing"), patch("sys.stdin", stdin):
                with self.assertRaisesRegex(SystemExit, "service is not installed"):
                    client.main()


class SemanticCompatibilityTests(unittest.TestCase):
    def test_clients_send_only_model_and_texts(self):
        for module in (index, search):
            with patch.object(module.subprocess, "run", return_value=subprocess.CompletedProcess(
                    [], 0, '{"embeddings":[[1.0,0.0]]}', "")) as run:
                vectors = module.embed(["text"], MODEL)
            self.assertEqual(vectors[0].tolist(), [1.0, 0.0])
            self.assertEqual(json.loads(run.call_args.kwargs["input"]),
                             {"model": MODEL, "input": ["text"]})
            self.assertNotIn("pass", run.call_args.args[0])

    def test_existing_database_search_formats_and_atomic_index_update(self):
        for corpus, source_type in (("library", "pdf"), ("wiki", "markdown")):
            with self.subTest(corpus=corpus), tempfile.TemporaryDirectory() as temporary:
                directory = Path(temporary)
                source = directory / "documents"
                source.mkdir()
                document = source / ("example.pdf" if source_type == "pdf" else "example.md")
                document.write_text("# Example\n" + "This is test content. " * 40)
                db_dir = directory / "index/pplx"
                db_dir.mkdir(parents=True)
                db = index.connect_db(db_dir / "index.sqlite")
                with patch.object(index, "embed", side_effect=lambda texts, model: [index.np.array([1, 0], dtype=index.np.float32) for _ in texts]), \
                     patch.object(index, "extract_pdf_pages", return_value=iter([(1, "test content " * 40)])), \
                     contextlib.redirect_stdout(io.StringIO()):
                    self.assertTrue(index.index_pdf(db, document, MODEL, source_type))
                before = db.execute("SELECT text, embedding FROM chunks").fetchall()
                with patch.object(index, "embed", side_effect=RuntimeError("service unavailable")), \
                     patch.object(index, "extract_pdf_pages", return_value=iter([(1, "new content " * 40)])), \
                     contextlib.redirect_stdout(io.StringIO()):
                    with self.assertRaises(RuntimeError):
                        index.index_pdf(db, document, MODEL, source_type)
                self.assertEqual(before, db.execute("SELECT text, embedding FROM chunks").fetchall())
                db.close()
                config = {corpus: {"type": source_type, "source": str(source), "index": str(directory / "index")}}
                for output_format in ("json", "compact", "text"):
                    output = io.StringIO()
                    with patch.object(search, "CORPORA", config), \
                         patch.object(search, "embed_query", return_value=search.np.array([1, 0], dtype=search.np.float32)), \
                         patch("sys.argv", ["semantic-search", corpus, "query", "--format", output_format]), \
                         contextlib.redirect_stdout(output):
                        search.main()
                    self.assertIn("example", output.getvalue())
                    if output_format == "json":
                        result = json.loads(output.getvalue())
                        self.assertIn("page" if source_type == "pdf" else "line", result[0])


if __name__ == "__main__":
    unittest.main(verbosity=2)
