"""Run installed esptool with a saved transcript and concise progress."""
import re
import subprocess
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding='utf-8')
root = Path(__file__).resolve().parents[1]
label, *args = sys.argv[1:]
log = root / 'logs' / f'{label}.log'
log.parent.mkdir(exist_ok=True)
process = subprocess.Popen([sys.executable, '-m', 'esptool', *args], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
last_pct = -10
buffer = ''
with log.open('w', encoding='utf-8') as output:
    while True:
        chunk = process.stdout.read1(8192)
        if not chunk:
            break
        text = chunk.decode('utf-8', errors='replace')
        output.write(text)
        output.flush()
        buffer += text
        while '\n' in buffer or '\b' in buffer:
            split = re.split(r'[\n\b]', buffer, maxsplit=1)
            if len(split) < 2:
                break
            line, buffer = split
            line = line.strip('\r ')
            if not line:
                continue
            match = re.search(r'(\d+)\s*%', line)
            if match:
                pct = int(match.group(1))
                if pct >= last_pct + 10 or pct == 100:
                    print(f'{label}: {pct}%', flush=True)
                    last_pct = pct
            else:
                print(line, flush=True)
    if buffer.strip():
        print(buffer.strip(), flush=True)
code = process.wait()
print(f'Log: {log}; exit={code}', flush=True)
sys.exit(code)
