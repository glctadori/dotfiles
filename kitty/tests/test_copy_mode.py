"""Run with kitty +runpy to use Kitty's installed Python API."""

import importlib.util
import json
import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("copy_mode", ROOT / ".config/kitty/copy-mode.py")
copy_mode = importlib.util.module_from_spec(spec)
spec.loader.exec_module(copy_mode)


class CopyModeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.session = self.root / "session.jsonl"
        self.session.write_text("\n".join(json.dumps(entry) for entry in [
            {"type": "session", "id": "session"},
            {"type": "message", "id": "u", "parentId": None,
             "message": {"role": "user", "content": "Domanda iniziale fuori schermo"}},
            {"type": "message", "id": "a", "parentId": "u",
             "message": {"role": "assistant", "content": [
                 {"type": "thinking", "thinking": "private reasoning"},
                 {"type": "text", "text": r"Formula $\frac{a}{b}$"},
                 {"type": "image", "data": "not copied"}]}},
            {"type": "message", "id": "unused", "parentId": "u",
             "message": {"role": "assistant", "content": "abandoned branch"}},
            {"type": "message", "id": "tool", "parentId": "a",
             "message": {"role": "toolResult", "content": "tool output"}},
            {"type": "custom", "id": "leaf", "parentId": "tool", "data": {}},
        ]) + '\n{"unfinished"', encoding="utf-8")
        self.metadata = json.dumps({"file": str(self.session), "leaf": "leaf"})

    def tearDown(self):
        self.tmp.cleanup()

    def test_reads_active_branch_including_offscreen_text_and_source_latex(self):
        text = copy_mode.pi_transcript(self.metadata)
        self.assertIn("Domanda iniziale fuori schermo", text)
        self.assertIn(r"$\frac{a}{b}$", text)
        self.assertLess(text.index("## Tu"), text.index("## Pi"))
        for excluded in ["private reasoning", "not copied", "abandoned branch", "tool output"]:
            self.assertNotIn(excluded, text)

    def test_invalid_or_unsaved_session_uses_terminal_fallback(self):
        for metadata in ["invalid", "null", "[]", "{}", json.dumps({"file": str(self.session), "leaf": "missing"})]:
            self.assertIsNone(copy_mode.pi_transcript(metadata))

    def test_branch_change_selects_new_branch(self):
        metadata = json.dumps({"file": str(self.session), "leaf": "unused"})
        text = copy_mode.pi_transcript(metadata)
        self.assertIn("abandoned branch", text)
        self.assertNotIn("Formula", text)

    def test_opens_private_snapshot_in_overlay_without_changing_session(self):
        original = self.session.read_bytes()
        window = SimpleNamespace(user_vars={"pi_copy_session": self.metadata})
        calls = []
        boss = SimpleNamespace(window_id_map={7: window},
                               call_remote_control=lambda window, args: calls.append(args))
        with patch.dict(os.environ, {"XDG_CACHE_HOME": str(self.root)}):
            copy_mode.handle_result([], None, 7, boss)
        args = calls[0]
        self.assertEqual(args[:2], ("launch", "--type=overlay"))
        self.assertIn("id:7", args)
        self.assertIn("NONE", args)
        self.assertIn("--noplugin", args)
        self.assertIn("Copy mode · Pi", args)
        from kitty.rc.base import command_for_name, parse_subcommand_cli
        options, command = parse_subcommand_cli(command_for_name("launch"), list(args))
        self.assertEqual(options.type, "overlay")
        self.assertEqual(options.source_window, "id:7")
        self.assertEqual(command[0], "nvim")
        snapshot = Path(args[-1])
        self.assertEqual(stat.S_IMODE(snapshot.stat().st_mode), 0o600)
        self.assertIn("Domanda iniziale fuori schermo", snapshot.read_text())
        self.assertEqual(self.session.read_bytes(), original)

    def test_generic_terminal_uses_full_plain_scrollback(self):
        requests = []
        window = SimpleNamespace(user_vars={}, as_text=lambda **kwargs: requests.append(kwargs) or "scrollback text")
        calls = []
        boss = SimpleNamespace(window_id_map={7: window},
                               call_remote_control=lambda window, args: calls.append(args))
        with patch.dict(os.environ, {"XDG_CACHE_HOME": str(self.root)}):
            copy_mode.handle_result([], None, 7, boss)
        self.assertEqual(requests, [{"as_ansi": False, "add_history": True}])
        self.assertEqual(Path(calls[0][-1]).read_text(), "scrollback text")
        self.assertIn("Copy mode · terminale", calls[0])

    def test_failed_launch_removes_temp_copy(self):
        def fail(*args):
            raise RuntimeError("launch failed")
        window = SimpleNamespace(user_vars={}, as_text=lambda **kwargs: "text")
        boss = SimpleNamespace(window_id_map={7: window}, call_remote_control=fail)
        with patch.dict(os.environ, {"XDG_CACHE_HOME": str(self.root)}):
            with self.assertRaises(RuntimeError):
                copy_mode.handle_result([], None, 7, boss)
        self.assertEqual(list((self.root / "kitty-copy-mode").iterdir()), [])

    def test_neovim_visual_yank_and_q_cleanup(self):
        cache = self.root / "kitty-copy-mode"
        cache.mkdir()
        snapshot = cache / "view-neovim.md"
        snapshot.write_text("prima riga\nseconda riga\nultima riga\n")
        clipboard = self.root / "clipboard.txt"
        env = dict(os.environ, XDG_CACHE_HOME=str(self.root), KITTY_COPY_FILE=str(snapshot),
                   COPY_TEST_LOG=str(clipboard))
        mock_clipboard = """lua
local copy=function(lines) vim.fn.writefile(lines,vim.env.COPY_TEST_LOG) end
local paste=function() return {{}, 'v'} end
vim.g.clipboard={name='test',copy={['+']=copy,['*']=copy},
  paste={['+']=paste,['*']=paste},cache_enabled=0}
"""
        checks = """lua
vim.api.nvim_create_autocmd('VimEnter',{once=true,callback=function()
  vim.schedule(function()
    local ok,err=pcall(function()
      assert(vim.o.clipboard=='unnamedplus')
      assert(not vim.bo.modifiable and vim.bo.readonly)
      assert(vim.fn.maparg('q','n')=='<Cmd>qa!<CR>')
      assert(vim.fn.maparg('q','x')=='<Cmd>qa!<CR>')
      vim.cmd('normal! ggVjy')
      local lines=vim.fn.readfile(vim.env.COPY_TEST_LOG)
      assert(lines[1]=='prima riga' and lines[2]=='seconda riga')
    end)
    if not ok then io.stderr:write(tostring(err)); vim.cmd('cquit'); return end
    vim.cmd('normal q')
  end)
end})
"""
        result = subprocess.run([
            "nvim", "--headless", "--noplugin", "-i", "NONE", "--cmd", mock_clipboard,
            "-u", str(ROOT / ".config/kitty/copy-mode.lua"), str(snapshot), "-c", checks,
        ], env=env, capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(clipboard.read_text().rstrip("\n"), "prima riga\nseconda riga")
        self.assertFalse(snapshot.exists())

    def test_stdin_pager_strips_ansi_and_links(self):
        checks = """lua
vim.api.nvim_create_autocmd('VimEnter',{once=true,callback=function()
  vim.schedule(function()
    local lines=vim.api.nvim_buf_get_lines(0,0,-1,false)
    if lines[1]~='rosso' or lines[2]~='link' then
      io.stderr:write(vim.inspect(lines)); vim.cmd('cquit'); return
    end
    vim.cmd('normal q')
  end)
end})
"""
        result = subprocess.run([
            "nvim", "--headless", "--noplugin", "-i", "NONE",
            "-u", str(ROOT / ".config/kitty/copy-mode.lua"), "-", "-c", checks,
        ], input='\x1b[31mrosso\x1b[0m\n\x1b]8;;https://example.org\x1b\\link\x1b]8;;\x1b\\\n',
            capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main(argv=[__file__])
