"""Read-only verification of the incident build and its distributable artifacts."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


manifest = json.loads((root / "firmware/current/manifest.json").read_text(encoding="utf-8"))
assert manifest == json.loads((root / "docs/horizontal_build.json").read_text(encoding="utf-8"))
assert manifest["BuildPassed"] and not manifest["FlightCauseConfirmed"]
assert not manifest["FlightReleaseApproved"]
verified = []
for model in manifest["Models"]:
    assert digest(root / model["Model"]) == model["ModelSHA256"], model["Model"]
    for binary in model["Binaries"]:
        path = root / binary["File"]
        assert digest(path) == binary["SHA256"], binary["File"]
        assert path.stat().st_size == binary["Bytes"], binary["File"]
        verified.append({"File": binary["File"], "SHA256": binary["SHA256"]})
for source in manifest["SourceHashes"]:
    assert digest(root / source["File"]) == source["SHA256"], source["File"]
for name in manifest["VerificationRecords"]:
    check = json.loads((root / "docs" / f"{name}.json").read_text(encoding="utf-8"))
    assert check.get("Passed", check.get("Failed") == 0 and check.get("Incomplete") == 0), name
invariants = json.loads((root / "docs/incident_invariants_verification.json").read_text(encoding="utf-8"))
assert invariants["ModelSHA256"] == digest(root / "StampFly_IMU400.slx")
distribution = json.loads((root / "docs/imu_distribution_verification.json").read_text(encoding="utf-8"))
assert distribution["Passed"] and distribution["ExternalCustomDependencies"] == 0
for item in distribution["TestedModels"]:
    assert digest(root / item["File"]) == item["SHA256"], item["File"]
for item in distribution["TestedAppFiles"]:
    contents = (root / item["File"]).read_bytes()
    assert item["HashNormalization"] == "LF"
    assert hashlib.sha256(contents.replace(b"\r\n", b"\n")).hexdigest() == item["SHA256"], item["File"]
# The archived manifest keeps its original paths; resolve the preserved artifacts here.
history_folder = root / "firmware/history/horizontal1801"
history = json.loads((history_folder / "manifest.json").read_text(encoding="utf-8"))
for model in history["Models"]:
    model_file = (root / "archive/snapshots/Horizontal1801.slx"
                  if model["Model"] == "StampFly_IMU400.slx" else root / model["Model"])
    assert digest(model_file) == model["ModelSHA256"], model["Model"]
    for binary in model["Binaries"]:
        path = history_folder / Path(binary["File"]).name
        assert digest(path) == binary["SHA256"], path.name
        assert path.stat().st_size == binary["Bytes"], path.name
print(json.dumps({"ModelBinarySourceAndVerificationHashesMatch": True,
                  "FreshCopyModelAndAppMatchCurrentFiles": True,
                  "Archived1801ArtifactsMatchOriginalManifest": True,
                  "SourceCount": len(manifest["SourceHashes"]), "Binaries": verified}, indent=2))
