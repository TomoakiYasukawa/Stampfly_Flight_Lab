"""List or read immutable project evidence without expanding the whole archive."""
from pathlib import Path
import argparse
import hashlib
import json
import sys
from zipfile import ZipFile

root = Path(__file__).resolve().parents[1]
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
parser = argparse.ArgumentParser(description=__doc__)
sub = parser.add_subparsers(dest="action", required=True)
listing = sub.add_parser("list")
listing.add_argument("--contains", default="")
show = sub.add_parser("show")
show.add_argument("name", help="OriginalPath from docs/history/index.json")
args = parser.parse_args()
index = json.loads((root / "docs/history/index.json").read_text(encoding="utf-8"))
if args.action == "list":
    for item in index["Records"]:
        if args.contains.lower() in item["OriginalPath"].lower():
            print(item["OriginalPath"])
else:
    matches = [item for item in index["Records"] if item["OriginalPath"] == args.name]
    if not matches:
        matches = [item for item in index["Records"] if Path(item["OriginalPath"]).name == args.name]
    if len(matches) != 1:
        parser.error("Record is missing or ambiguous. Use its full original path.")
    item = matches[0]
    with ZipFile(root / "docs/history" / index["Archive"]) as archive:
        contents = archive.read(item["Entry"])
    assert hashlib.sha256(contents).hexdigest() == item["SHA256"], "Record digest mismatch"
    print(contents.decode("utf-8-sig", errors="replace"))
