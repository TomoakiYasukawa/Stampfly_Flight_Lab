"""Read-only verification of the incident build and its distributable artifacts."""
import hashlib
import json
from pathlib import Path
from zipfile import ZipFile

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
# Build manifests intentionally retain the original hashes. Host-only logger
# changes can differ; their build-time contents remain in the verified archive.
host_updates = []
source_archive = root / "firmware/history/horizontal1804/sources.zip"
with ZipFile(source_archive) as saved_sources:
    for source in manifest["SourceHashes"]:
        name = source["File"]
        assert hashlib.sha256(saved_sources.read(name)).hexdigest() == source["SHA256"], name
        if digest(root / name) != source["SHA256"]:
            assert name in {"code/+imu/RecordingHistoryView.m",
                            "code/+imu/readRecordingHistory.m"}, name
            host_updates.append(name)
for name in manifest["VerificationRecords"]:
    check = json.loads((root / "docs" / f"{name}.json").read_text(encoding="utf-8"))
    assert check.get("Passed", check.get("Failed") == 0 and check.get("Incomplete") == 0), name
invariants = json.loads((root / "docs/incident_invariants_verification.json").read_text(encoding="utf-8"))
assert invariants["ModelSHA256"] == digest(root / "StampFly_IMU400.slx")
distribution = json.loads((root / "docs/logger_app_distribution_verification.json").read_text(encoding="utf-8"))
assert distribution["Passed"] and distribution["ExternalCustomDependencies"] == 0
for item in distribution["TestedModels"]:
    assert digest(root / item["File"]) == item["SHA256"], item["File"]
for item in distribution["TestedAppFiles"]:
    contents = (root / item["File"]).read_bytes()
    assert item["HashNormalization"] == "LF"
    assert hashlib.sha256(contents.replace(b"\r\n", b"\n")).hexdigest() == item["SHA256"], item["File"]
for item in distribution["TestedHostSources"]:
    assert digest(root / item["File"]) == item["SHA256"], item["File"]
app_checks=json.loads((root / "docs/logger_app_verification.json").read_text(encoding="utf-8"))
assert app_checks["Passed"] and app_checks["Failed"] == 0 and app_checks["Incomplete"] == 0
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
                  "BuildTimeSourcesPreservedInArchive": True,
                  "HostOnlyLoggerSourcesUpdated": host_updates,
                  "SourceCount": len(manifest["SourceHashes"]), "Binaries": verified}, indent=2))
