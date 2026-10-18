"""Copy distributable project files to an isolated directory for MATLAB checks."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import tempfile

root = Path(__file__).resolve().parents[1]
# プロジェクト直下に複製すると未参照の子プロジェクトとして検出されるため、
# 一意な一時フォルダーへ置く。過去の検証コピーは上書きしない。
verification_root = Path(tempfile.mkdtemp(prefix="StampFly_distribution_check_"))
destination = verification_root / "stampfly_lab"
excluded_roots = {".git", "build", "logs", "recordings", "backups", ".runtime_temp"}
generated_dirs = {".git", "slprj", "__pycache__", ".runtime_temp"}
generated_suffixes = {".slxc", ".asv", ".autosave", ".pyc", ".obj", ".o", ".elf", ".map"}
names = []
for folder, dirs, files in os.walk(root):
    base = Path(folder)
    dirs[:] = sorted(d for d in dirs if d not in generated_dirs
                     and not d.endswith("_ert_rtw")
                     and not (base == root and d in excluded_roots))
    for name in sorted(files):
        source = base / name
        if source.suffix in generated_suffixes or source.suffix.startswith(".mex"):
            continue
        if source.is_file():
            names.append(source.relative_to(root).as_posix())
names.sort()
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
manifest.write_text(json.dumps({"Source": str(root), "Destination": str(destination),
                               "Files": records, "GitCommandsExecuted": False},
                              ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"Copied {len(records)} distribution files with identical SHA-256.")
print(f"Verification project: {destination / 'StampFly_Lab.prj'}")
print(f"Copy manifest: {manifest}")
