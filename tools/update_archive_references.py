"""Update file locations after the IMU distribution cleanup, without editing SLX."""
from pathlib import Path
import json
import re

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root / "docs/imu_distribution_moves.json").read_text(encoding="utf-8-sig"))
mapping = {item["From"]: item["To"] for item in manifest}
for item in json.loads((root / "archive/aircraft/manifest.json").read_text(encoding="utf-8"))["Models"]:
    mapping[item["OriginalPath"]] = item["ArchivedPath"]
mapping.update({
    "StampFly_KF400.slx": "archive/kf400/StampFly_KF400.slx",
    "firmware/kf400/StampFly_KF400.bin": "archive/kf400/firmware/StampFly_KF400.bin",
    "firmware/kf400/StampFly_KF400.bootloader.bin": "archive/kf400/firmware/StampFly_KF400.bootloader.bin",
    "firmware/kf400/StampFly_KF400.partitions.bin": "archive/kf400/firmware/StampFly_KF400.partitions.bin",
})
changed = []

def location(text):
    # Exact fullfile(root,...) fragments, retaining literal strings and newlines.
    for old, new in sorted(mapping.items(), key=lambda p: -len(p[0])):
        parts = old.split("/")
        pattern = r"fullfile\(root,\s*" + r",\s*".join(re.escape("'" + p + "'") for p in parts) + r"\)"
        text = re.sub(pattern, "fullfile(root," + ",".join("'" + p + "'" for p in new.split("/")) + ")", text)
        text = text.replace("'" + old + "'", "'" + new + "'")
        text = text.replace('"' + old + '"', '"' + new + '"')
    return text

for path in (root / "archive/maintenance").rglob("*"):
    if path.suffix not in {".m", ".py", ".ps1"}:
        continue
    before = path.read_text(encoding="utf-8-sig")
    after = location(before)
    if path.suffix == ".m":
        # Historical reports were collected under docs/history.
        after = re.sub(r"fullfile\(root,\s*'docs',\s*'(?!history')[^']+'", lambda m: m.group(0).replace("'docs',", "'docs','history',", 1), after)
        after = after.replace("fullfile(root,[model '.slx'])", "stampfly_model_file(model)")
        after = after.replace("fullfile(root,'StampFly_IMU400.slx')", "fullfile(root,'archive','kf400','baseline','StampFly_IMU400.slx')")
        after = after.replace("fileparts(fileparts(fileparts(mfilename('fullpath'))))", "stampfly_project_root()")
    elif path.suffix == ".py":
        after = after.replace("Path(__file__).resolve().parents[1]", "Path(__file__).resolve().parents[3]")
        after = after.replace('root / "docs" /', 'root / "docs" / "history" /')
        after = after.replace("root / 'docs' /", "root / 'docs' / 'history' /")
        after = after.replace('root / "tools"', 'root / "archive" / "maintenance" / "tools"')
        after = after.replace("root / 'tools'", "root / 'archive' / 'maintenance' / 'tools'")
        # Shared serial tooling remains at the project root's tools directory.
        for name in ("run_esptool.py", "list_devices.py", "capture_imu_startup.py", "serial_monitor.py"):
            after = after.replace('root / "archive" / "maintenance" / "tools" / "' + name + '"', 'root / "tools" / "' + name + '"')
            after = after.replace("root / 'archive' / 'maintenance' / 'tools' / '" + name + "'", "root / 'tools' / '" + name + "'")
    else:
        after = after.replace("Split-Path -Parent $PSScriptRoot", "Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))")
    if after != before:
        path.write_text(after, encoding="utf-8")
        changed.append(path.relative_to(root).as_posix())

# Historical JSON evidence retains measured values/hashes, updating paths only.
def relocate(value):
    if isinstance(value, dict):
        return {key: relocate(item) for key, item in value.items()}
    if isinstance(value, list):
        return [relocate(item) for item in value]
    if isinstance(value, str):
        normalized = value.replace("\\", "/")
        for old, new in mapping.items():
            if normalized == old:
                return new
            prefix = root.as_posix() + "/"
            if normalized.lower() == (prefix + old).lower():
                return new
        if normalized.startswith("docs/") and not normalized.startswith("docs/history/"):
            return "docs/history/" + normalized[5:]
    return value

for path in (root / "docs/history").glob("*.json"):
    try:
        before = json.loads(path.read_text(encoding="utf-8-sig"))
    except json.JSONDecodeError:
        continue
    after = relocate(before)
    if after != before:
        path.write_text(json.dumps(after, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        changed.append(path.relative_to(root).as_posix())

for path in (root / "docs/history").glob("*.md"):
    before = path.read_text(encoding="utf-8-sig")
    def relink(match):
        label, target = match.groups()
        if target.startswith(("https:", "http:", "#", "mailto:")):
            return match.group(0)
        base, *fragment = target.split("#", 1)
        # Copied README guides originally used root-relative docs/ links.
        if base.startswith("docs/"):
            base = base[5:]
        elif base.startswith("../"):
            old = base[3:]
            if old in mapping:
                base = "../../" + mapping[old]
            elif old in {"StampFly_IMU400.slx", "M5Stamp_IMU_Rx.slx", "StampFly_Official.prj"}:
                base = "../../" + old
        elif base in mapping:
            base = "../../" + mapping[base]
        elif base in {"StampFly_IMU400.slx", "M5Stamp_IMU_Rx.slx"}:
            base = "../../" + base
        return "[" + label + "](" + base + ("#" + fragment[0] if fragment else "") + ")"
    after = re.sub(r"\[([^\]]*)\]\(([^\s)]+)\)", relink, before)
    if after != before:
        path.write_text(after, encoding="utf-8")
        changed.append(path.relative_to(root).as_posix())

print(f"Updated location references in {len(changed)} files.")
