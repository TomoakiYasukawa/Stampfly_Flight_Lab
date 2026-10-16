import hashlib
import json
import sys
import urllib.request
from pathlib import Path

sys.stdout.reconfigure(encoding='utf-8')
root = Path(__file__).resolve().parents[3] / 'official_sources'
for repo, path in [('M5StampFly', 'firmware'), ('Atom-JoyStick', 'examples/StampFlyController/firmware')]:
    url = f'https://api.github.com/repos/m5stack/{repo}/contents/{path}'
    items = json.loads(urllib.request.urlopen(url, timeout=45).read())
    print(repo, json.dumps([(x['name'], x['type'], x.get('size'), x.get('download_url')) for x in items], ensure_ascii=False))
    (root / f'{repo}-firmware-contents.json').write_text(json.dumps(items, indent=2), encoding='utf-8')
    for item in items:
        if item['type'] == 'file' and item['name'].endswith('.bin'):
            data = urllib.request.urlopen(item['download_url'], timeout=45).read()
            (root / item['name']).write_bytes(data)
            print('DOWNLOADED', item['name'], len(data), hashlib.sha256(data).hexdigest())
print((root / 'firmware.txt').read_text(encoding='utf-8')[-24000:])
