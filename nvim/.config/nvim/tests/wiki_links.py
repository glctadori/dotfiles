"""Integration test: python3 nvim/.config/nvim/tests/wiki_links.py (requires pynvim)."""
import pathlib
import tempfile
import time

import pynvim


def wait(predicate):
    deadline = time.monotonic() + 8
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(0.02)
    raise AssertionError("Timed out")


with tempfile.TemporaryDirectory(prefix="wiki-links-") as directory:
    root = pathlib.Path(directory)
    for name in ["index.md", "piano-rover-agricolo.md", "sub/source.md", "other/target.md", "space page.md"]:
        file = root / name
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text("prima DOPO\n")
    (root / "excluded.txt").write_text("not a wiki page")
    config = pathlib.Path(__file__).resolve().parents[1]
    plugins = pathlib.Path.home() / ".local/share/nvim/lazy"
    nvim = pynvim.attach("child", argv=["nvim", "--embed", "--headless", "-u", "NONE"])
    nvim.ui_attach(100, 35, rgb=True)
    try:
        nvim.exec_lua("""
          local config, plugins, root = ...
          vim.opt.rtp:prepend(config)
          vim.opt.rtp:append(plugins .. '/snacks.nvim')
          vim.opt.rtp:append(plugins .. '/vimwiki')
          vim.g.mapleader = ' '
          vim.opt.hidden = true
          vim.g.vimwiki_list = {{path = root, syntax = 'markdown', ext = '.md'}}
          vim.g.vimwiki_global_ext = 0
          vim.cmd('runtime plugin/vimwiki.vim')
          vim.cmd('filetype plugin on')
          require('snacks').setup({picker = {enabled = true}})
          require('wiki_links').setup()
        """, str(config), str(plugins), directory)

        def prepare(source):
            nvim.input("\x1b")
            wait(lambda: nvim.eval("mode()") == "n")
            nvim.command("edit! " + str(root / source))
            nvim.current.buffer[:] = ["prima DOPO"]
            nvim.current.window.cursor = (1, 6)
            return nvim.current.buffer.number, nvim.current.window.handle

        def pick(keys, search):
            nvim.input(keys)
            wait(lambda: nvim.exec_lua("return #Snacks.picker.get() == 1"))
            wait(lambda: nvim.eval("mode()") == "i")
            nvim.input(search)
            wait(lambda: nvim.exec_lua("""
              local p = Snacks.picker.get()[1]
              return p and not p:is_active() and p.list:count() == 1 and p:current() ~= nil
            """))
            assert nvim.exec_lua("return Snacks.picker.get()[1]:current().cwd") == directory
            nvim.input("\r")
            wait(lambda: nvim.exec_lua("return #Snacks.picker.get() == 0"))

        for source, search, destination in [
            ("index.md", "piano-rover-agricolo", "piano-rover-agricolo"),
            ("index.md", "other/target", "other/target"),
            ("sub/source.md", "other/target", "../other/target"),
            ("sub/source.md", "piano-rover-agricolo", "../piano-rover-agricolo"),
            ("index.md", "space page", "<space page>"),
        ]:
            for insert in [False, True]:
                buf, win = prepare(source)
                pick("i[[" if insert else " wi", search)
                label = search.split("/")[-1]
                link = f"[{label}]({destination})"
                expected = "prima " + link + "DOPO"
                wait(lambda: nvim.current.buffer[0] == expected)
                assert nvim.current.buffer.number == buf and nvim.current.window.handle == win
                url = destination.strip("<>")
                resolved = nvim.call("vimwiki#base#resolve_link", url, str(root / source))
                assert pathlib.Path(resolved["filename"]).resolve() == root / (search + ".md")
                if insert:
                    wait(lambda: nvim.eval("mode()") == "i")
                    nvim.input("X")
                    wait(lambda: nvim.current.buffer[0] == "prima " + link + "XDOPO")
                else:
                    assert nvim.current.window.cursor == (1, 6)
                nvim.input("\x1b")
                wait(lambda: nvim.eval("mode()") == "n")
                nvim.current.window.cursor = (1, 7)
                nvim.command("VimwikiFollowLink")
                assert pathlib.Path(nvim.current.buffer.name) == root / (search + ".md")
                print(f"PASS {'Insert' if insert else 'Normal'} {source} -> {destination}")

        # End of line and cancellation must preserve the insertion column/mode.
        prepare("index.md")
        pick("A[[", "piano-rover-agricolo")
        nvim.input("X")
        wait(lambda: nvim.current.buffer[0] == "prima DOPO[piano-rover-agricolo](piano-rover-agricolo)X")
        prepare("index.md")
        nvim.input("i[[")
        wait(lambda: nvim.exec_lua("return #Snacks.picker.get() == 1"))
        wait(lambda: nvim.exec_lua("local p = Snacks.picker.get()[1]; return p:is_focused() and not p:is_active()") and nvim.eval("mode()") == "i")
        nvim.input("\x1b")
        wait(lambda: nvim.eval("mode()") == "n")
        nvim.input("\x1b")
        wait(lambda: nvim.eval("mode()") == "i" and nvim.current.buffer.name == str(root / "index.md"))
        nvim.input("X")
        wait(lambda: nvim.current.buffer[0] == "prima XDOPO")
        nvim.input("\x1b")
        wait(lambda: nvim.eval("mode()") == "n")
        nvim.command("edit! " + str(root.parent / "outside.md"))
        nvim.command("setfiletype markdown")
        assert not nvim.call("maparg", "[[", "i")
        print("PASS end of line, cancellation, outside-wiki mapping scope")
    finally:
        try:
            nvim.command("qa!")
        except EOFError:
            pass
