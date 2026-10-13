#!/usr/bin/env python3
"""Offline regression tests: python3 nvim/.config/nvim/tests/chat.py."""
import json
import os
from pathlib import Path
import queue
import subprocess
import tempfile
import threading
import unittest

ROOT = Path(__file__).resolve().parents[4]
SCRIPT = ROOT / 'scripts/.local/bin/chat'

class Protocol(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        fake = self.dir / 'llm'
        fake.write_text('''#!/usr/bin/env python3
import json, os, sys, time
from pathlib import Path
text=sys.stdin.read()
if 'Per questo turno prepara soltanto una ricerca web' in text:
 Path(os.environ['CAPTURE']+'-plan').write_text(text)
 print(json.dumps({'objective':'Documentation from conversation','search_queries':['contextual documentation']}),flush=True)
 sys.exit(0)
Path(os.environ['CAPTURE']).write_text(json.dumps({'args':sys.argv[1:],'text':text}))
if 'CLOSED' in text:
 print('partial',flush=True)
 os.close(1)
 time.sleep(30)
if 'SLOW' in text:
 print('partial',flush=True)
 time.sleep(30)
if 'FAIL' in text:
 print('stderr-only',file=sys.stderr,flush=True)
 sys.exit(3)
if 'EMPTY' in text:
 sys.exit(0)
print('fake answer',flush=True)
''')
        fake.chmod(0o755)
        self.env = dict(os.environ, HOME=str(self.dir), PATH=f'{self.dir}:/usr/bin:/bin', CAPTURE=str(self.dir/'capture'))
        self.proc = subprocess.Popen([str(SCRIPT),'--pipe'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,env=self.env)
        self.lines = queue.Queue()
        def read():
            for line in self.proc.stdout:
                self.lines.put(line.rstrip('\n'))
            self.lines.put('EOF')
        self.reader = threading.Thread(target=read,daemon=True)
        self.reader.start()

    def tearDown(self):
        if self.proc.poll() is None:
            self.proc.stdin.close()
            try: self.proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                self.proc.kill(); self.proc.wait()
        self.proc.stdout.close(); self.proc.stderr.close()
        self.tmp.cleanup()

    def send(self, **request):
        self.proc.stdin.write(json.dumps(request)+'\n'); self.proc.stdin.flush()

    def terminal(self, expected):
        output=[]
        while True:
            line=self.lines.get(timeout=5)
            self.assertNotEqual(line,'EOF')
            if line.startswith('__CHAT_RESPONSE_'):
                self.assertEqual(line,f'__CHAT_RESPONSE_{expected}__')
                return '\n'.join(output)
            output.append(line)

    def test_attachments_config_and_context(self):
        image=self.dir/'image.png'; image.write_bytes(b'fake')
        self.send(type='config',model='deepseek/deepseek-v4.1-flash',reasoning='high')
        self.send(type='file',path=str(image),prompt='describe')
        self.terminal('DONE')
        capture=json.loads((self.dir/'capture').read_text())
        self.assertEqual(capture['args'],['-m','deepseek/deepseek-v4.1-flash','-r','high','-f',str(image)])
        self.send(type='context',name='target',text='unsaved αβ',prompt='edit')
        self.terminal('DONE')
        capture=json.loads((self.dir/'capture').read_text())
        self.assertIn('unsaved αβ',capture['text']); self.assertIn('describe',capture['text'])
        self.assertNotIn('-f',capture['args'])

    def fake_search(self, slow=False, fail=False):
        fake = self.dir / 'curl'
        fake.write_text('''#!/usr/bin/env python3
import json, sys, time
from pathlib import Path
path = Path(__file__).with_name('search-calls')
with path.open('a') as f: f.write('search\\n')
Path(__file__).with_name('search-payload').write_text(sys.argv[-1])
''' + ('time.sleep(30)\n' if slow else '') + (
            "print('search unavailable',file=sys.stderr); sys.exit(22)\n" if fail else
            "print(json.dumps({'jsonrpc':'2.0','id':1,'result':{'structuredContent':{'results':[{'url':'https://example.org/source','title':'Example','excerpts':['source excerpt']}]}}}))\n"))
        fake.chmod(0o755)

    def test_web_history_and_explicit_search(self):
        self.fake_search()
        self.send(type='message',text='Earlier conversation')
        self.terminal('DONE')
        self.send(type='message',text='Find documentation',web=True)
        self.terminal('DONE')
        capture=json.loads((self.dir/'capture').read_text())
        self.assertIn('Earlier conversation',capture['text'])
        self.assertIn('Earlier conversation',(self.dir/'capture-plan').read_text())
        payload=json.loads((self.dir/'search-payload').read_text())
        self.assertEqual(payload['params']['arguments']['search_queries'],['contextual documentation'])
        self.assertIn('https://example.org/source',capture['text'])
        self.send(type='message',text='Explain that source')
        self.terminal('DONE')
        capture=json.loads((self.dir/'capture').read_text())
        self.assertIn('source excerpt',capture['text'])
        self.assertEqual((self.dir/'search-calls').read_text(),'search\n')

    def test_web_failure_and_cancel(self):
        self.fake_search(fail=True)
        self.send(type='message',text='Failed search',web=True)
        self.terminal('ERROR')
        self.assertFalse((self.dir/'capture').exists())
        self.fake_search(slow=True)
        self.send(type='message',text='Cancelled search',web=True)
        import time
        time.sleep(0.15)
        self.send(type='cancel')
        self.terminal('CANCELLED')
        self.send(type='message',text='Normal followup')
        self.terminal('DONE')
        capture=json.loads((self.dir/'capture').read_text())
        self.assertNotIn('Failed search',capture['text'])
        self.assertNotIn('Cancelled search',capture['text'])

    def test_errors_recover(self):
        self.send(type='file',path=str(self.dir/'absent'))
        self.terminal('ERROR')
        binary=self.dir/'binary.dat'; binary.write_bytes(b'\xff\xfe')
        self.send(type='file',path=str(binary)); self.terminal('ERROR')
        self.send(type='message',text='FAIL'); self.terminal('ERROR')
        self.send(type='message',text='ok'); self.terminal('DONE')
        self.assertNotIn('FAIL',json.loads((self.dir/'capture').read_text())['text'])
        (self.dir/'llm').unlink()
        self.send(type='message',text='missing executable'); self.terminal('ERROR')

    def test_stop_clear_and_new_request(self):
        self.send(type='message',text='SLOW')
        self.assertEqual(self.lines.get(timeout=5),'partial')
        self.send(type='cancel'); self.terminal('CANCELLED')
        self.send(type='message',text='new'); self.terminal('DONE')
        self.send(type='message',text='SLOW')
        self.assertEqual(self.lines.get(timeout=5),'partial')
        self.send(type='clear'); self.terminal('CANCELLED')
        self.send(type='message',text='fresh'); self.terminal('DONE')
        transcript=json.loads((self.dir/'capture').read_text())['text']
        self.assertNotIn('SLOW',transcript); self.assertNotIn('USER:\nnew',transcript)

    def test_closed_stdout_can_still_be_cancelled(self):
        self.send(type='message',text='CLOSED')
        self.assertEqual(self.lines.get(timeout=5),'partial')
        self.send(type='cancel'); self.terminal('CANCELLED')
        self.send(type='message',text='recovered'); self.terminal('DONE')

    def test_eof_during_stream(self):
        self.send(type='message',text='SLOW')
        self.assertEqual(self.lines.get(timeout=5),'partial')
        self.proc.stdin.close(); self.terminal('CANCELLED')
        self.proc.wait(timeout=3)

    def capture(self):
        return json.loads((self.dir/'capture').read_text())

    def session_messages(self):
        files=list((self.dir/'.cache/chat').glob('chat-*.json'))
        self.assertEqual(len(files),1)
        return json.loads(files[0].read_text())['messages']

    def test_contextual_and_isolated_readonly(self):
        self.send(type='message',text='Previous decision: preserve headings')
        self.terminal('DONE')
        original=self.session_messages()
        self.send(type='context',name='target',text='unsaved content',
                  prompt='TECHNICAL_FORMAT_ONLY',history='readonly',use_history=True)
        self.terminal('DONE')
        self.assertIn('Previous decision',self.capture()['text'])
        self.assertIn('unsaved content',self.capture()['text'])
        self.assertEqual(self.session_messages(),original)
        self.send(type='context',text='isolated',prompt='isolate',
                  history='readonly',use_history=False)
        self.terminal('DONE')
        self.assertNotIn('Previous decision',self.capture()['text'])
        self.assertEqual(self.session_messages(),original)
        self.send(type='note',text='Proposal rejected; preserve headings instead')
        self.send(type='message',text='Try another proposal')
        self.terminal('DONE')
        transcript=self.capture()['text']
        self.assertIn('Proposal rejected',transcript)
        self.assertNotIn('TECHNICAL_FORMAT_ONLY',transcript)

    def test_request_overrides_leave_defaults_unchanged(self):
        self.send(type='config',model='deepseek/deepseek-v4.1-flash',reasoning='none')
        self.send(type='message',text='override',model='openai/gpt-6.1-sol',reasoning='high')
        self.terminal('DONE')
        self.assertEqual(self.capture()['args'],['-m','openai/gpt-6.1-sol','-r','high'])
        self.send(type='context',text='target',prompt='override thinking',
                  reasoning='medium',history='readonly',use_history=False)
        self.terminal('DONE')
        self.assertEqual(self.capture()['args'],['-m','deepseek/deepseek-v4.1-flash','-r','medium'])
        self.send(type='message',text='default')
        self.terminal('DONE')
        self.assertEqual(self.capture()['args'],['-m','deepseek/deepseek-v4.1-flash','-r','none'])

    def test_readonly_failures_cancel_and_empty_do_not_change_history(self):
        self.send(type='message',text='previous')
        self.terminal('DONE')
        original=self.session_messages()
        for prompt in ('FAIL','EMPTY'):
            self.send(type='context',text='target',prompt=prompt,history='readonly')
            self.terminal('ERROR')
            self.assertEqual(self.session_messages(),original)
        self.send(type='context',text='target',prompt='SLOW',history='readonly')
        self.assertEqual(self.lines.get(timeout=5),'partial')
        self.send(type='cancel'); self.terminal('CANCELLED')
        self.assertEqual(self.session_messages(),original)
        self.send(type='context',text='target',prompt='SLOW',history='readonly')
        self.assertEqual(self.lines.get(timeout=5),'partial')
        self.send(type='clear'); self.terminal('CANCELLED')
        self.send(type='message',text='fresh'); self.terminal('DONE')
        self.assertNotIn('previous',self.capture()['text'])

    def test_invalid_request_options_do_not_generate(self):
        for options in ({'reasoning':'max'},{'history':'unknown'},
                        {'use_history':'false'},{'model':''}):
            self.send(type='message',text='invalid',**options)
            self.terminal('ERROR')
            self.assertFalse((self.dir/'capture').exists())
        self.send(type='message',text='recovered'); self.terminal('DONE')

class Lua(unittest.TestCase):
    def test_headless(self):
        result=subprocess.run(['nvim','--headless','-u','NONE','-l',str(Path(__file__).with_suffix('.lua'))],env=dict(os.environ,CHAT_ROOT=str(ROOT)),capture_output=True,text=True,timeout=20)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)

    def test_real_snacks_picker(self):
        snacks=Path.home()/'.local/share/nvim/lazy/snacks.nvim'
        if not snacks.is_dir():
            self.skipTest('Snacks not installed locally')
        result=subprocess.run(['nvim','--headless','-u','NONE','-l',str(Path(__file__).with_suffix('.lua'))],
                              env=dict(os.environ,CHAT_ROOT=str(ROOT),CHAT_REAL_PICKER='1',SNACKS_ROOT=str(snacks)),
                              capture_output=True,text=True,timeout=15)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)

if __name__ == '__main__': unittest.main(verbosity=2)
