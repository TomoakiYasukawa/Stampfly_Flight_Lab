import io
import json
import sys
import urllib.request
import zipfile
from pathlib import Path

sys.stdout.reconfigure(encoding='utf-8')
root = Path(__file__).resolve().parents[1] / 'official_sources'
for repo, sub in [('M5StampFly', ''), ('Atom-JoyStick', 'examples/StampFlyController/')]:
    commit = json.loads(urllib.request.urlopen(f'https://api.github.com/repos/m5stack/{repo}/commits/main', timeout=45).read())['sha']
    url = f'https://codeload.github.com/m5stack/{repo}/zip/{commit}'
    data = urllib.request.urlopen(url, timeout=45).read()
    (root / f'{repo}-{commit}.zip').write_bytes(data)
    dest = root / repo
    dest.mkdir(exist_ok=True)
    count = 0
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        prefix = f'{repo}-{commit}/{sub}'
        for member in archive.infolist():
            if member.is_dir() or not member.filename.startswith(prefix):
                continue
            rel = member.filename[len(prefix):]
            target = (dest / rel).resolve()
            if not target.is_relative_to(dest.resolve()):
                raise RuntimeError('Unsafe archive path')
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(archive.read(member))
            count += 1
    (dest / 'upstream_commit.txt').write_text(commit + '\n', encoding='utf-8')
    print(repo, commit, len(data), count)
