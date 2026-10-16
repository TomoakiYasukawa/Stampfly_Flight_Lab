import json
import re
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'official_sources'
OUT.mkdir(exist_ok=True)

def fetch(url):
    req = urllib.request.Request(url, headers={'User-Agent': 'StampFly-official-setup'})
    return urllib.request.urlopen(req, timeout=45).read()

for repo, path in [('M5StampFly', ''), ('Atom-JoyStick', 'examples/StampFlyController')]:
    url = f'https://api.github.com/repos/m5stack/{repo}/contents/{path}'
    items = json.loads(fetch(url))
    print(repo, [(x['name'], x['type']) for x in items])
    (OUT / f'{repo}-contents.json').write_text(json.dumps(items, indent=2), encoding='utf-8')
    for item in items:
        if item['type'] == 'file' and (item['name'].lower().startswith('readme') or item['name'].endswith(('.ino', '.json', '.ini'))):
            data = fetch(item['download_url'])
            (OUT / f"{repo}-{item['name']}").write_bytes(data)
            print(item['name'], data.decode('utf-8', errors='replace')[:24000])

for page in ['firmware', 'play']:
    url = f'https://docs.m5stack.com/en/guide/stampfly/{page}'
    try:
        data = fetch(url).decode('utf-8')
        (OUT / f'{page}.html').write_text(data, encoding='utf-8')
        from bs4 import BeautifulSoup
        soup = BeautifulSoup(data, 'html.parser')
        article = soup.find('article') or soup.find('main') or soup
        for x in article(['script', 'style']):
            x.decompose()
        text = article.get_text('\n', strip=True)
        (OUT / f'{page}.txt').write_text(text, encoding='utf-8')
        print(url, text[-30000:])
        print('LINKS', [(a.get_text(' ', strip=True), a.get('href')) for a in article.find_all('a', href=True) if re.search('burn|firm|stamp|atom|github', a.get('href', ''), re.I)])
    except Exception as exc:
        print(url, type(exc).__name__, str(exc))
