"""Copy distributable project files to an isolated directory for MATLAB checks."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
# プロジェクト直下に複製すると未参照の子プロジェクトとして検出されるため、
# 一意な一時フォルダーへ置く。過去の検証コピーは上書きしない。
verification_root = Path(tempfile.mkdtemp(prefix="StampFly_distribution_check_"))
destination = verification_root / "Official_setup"
result = subprocess.run(
    ["git", "-c", "core.quotepath=false", "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
    cwd=root, check=True, capture_output=True,
)
names = sorted(set(result.stdout.decode("utf-8").strip("\0").split("\0")))
records = []
for name in names:
    source = root / name
    if not name or not source.is_file():
        continue
    target = destination / name
    assert target.resolve().is_relative_to(destination.resolve())
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)
    source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
    assert hashlib.sha256(target.read_bytes()).hexdigest() == source_hash
    records.append({"File": name, "SHA256": source_hash})
manifest = destination.parent / "copy_manifest.json"
manifest.write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"Copied {len(records)} distribution files with identical SHA-256.")
print(f"Verification project: {destination / 'StampFly_Official.prj'}")
print(f"Copy manifest: {manifest}")
