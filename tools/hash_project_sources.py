"""Hash the embedded MATLAB/C/C++ sources with no MATLAB Java dependency."""
import hashlib
import json
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
files = set((root / "code").rglob("*.m"))
for pattern in ("*.cpp", "*.c", "*.h"):
    files.update((root / "src").rglob(pattern))
files.update((root / "scripts/setup").glob("*.m"))
records = [{"File": file.relative_to(root).as_posix(),
            "SHA256": hashlib.sha256(file.read_bytes()).hexdigest()}
           for file in sorted(files, key=lambda f: f.relative_to(root).as_posix())]
sys.stdout.write(json.dumps(records))
