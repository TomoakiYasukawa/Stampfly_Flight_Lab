"""Back up, flash and verify only the configured aircraft/receiver app partitions."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import sys

from serial.tools import list_ports

sys.stdout.reconfigure(encoding="utf-8")
parser = argparse.ArgumentParser()
parser.add_argument("--device", choices=("aircraft", "receiver"), required=True)
parser.add_argument("--port", required=True)
parser.add_argument("--usb-only", action="store_true", required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
model_name, mac = {
    "aircraft": ("StampFly_IMU400.slx", "70:AF:09:DF:A6:C4"),
    "receiver": ("M5Stamp_IMU_Rx.slx", "10:51:DB:55:A1:60"),
}[args.device]


def digest(file):
    return hashlib.sha256(file.read_bytes()).hexdigest()


def read(name):
    return json.loads((root / name).read_text(encoding="utf-8"))


manifest = read("firmware/current/manifest.json")
assert manifest == read("docs/horizontal_build.json") and manifest["BuildPassed"]
build = next(m for m in manifest["Models"] if m["Model"] == model_name)
assert build["BuildPassed"] and build["BuildAction"] == "Build"
assert digest(root / model_name) == build["ModelSHA256"]
for source in manifest["SourceHashes"]:
    assert digest(root / source["File"]) == source["SHA256"], f"Source changed: {source['File']}"
for name in manifest["VerificationRecords"]:
    check = read(f"docs/{name}.json")
    assert check.get("Passed", check.get("Failed") == 0 and check.get("Incomplete") == 0)
invariants = read("docs/incident_invariants_verification.json")
assert invariants["ModelSHA256"] == digest(root / "StampFly_IMU400.slx")
assert invariants["PIDParametersPreserved"] and invariants["SupervisorUnchanged"]
assert not manifest["FlightReleaseApproved"], "Incident build is for USB-only bench diagnosis."
settings = build["Settings"]
if args.device == "aircraft":
    assert build["Step"] == .0025 and settings["PIDCount"] == 7
    assert settings["PWMHz"] == 150000 and settings["PWMBits"] == 8
    assert settings["MotorOutputEnabled"] and settings["ExistingPIDParametersPreserved"]
    assert settings["CorrectedAngularVelocityToPID"] and settings["RawToFModeIndependent"]
    assert settings["HorizontalAssistEnabled"] and settings["HorizontalSupplementBytes"] == 182
    assert settings["AltitudeKalmanImplementation"] == "MATLAB Function"
    assert not settings["AltitudeControlTiltCompensated"]
    assert settings["BuildID"] == 1401 and settings["FirmwareRevision"] == 1802
    assert settings["VerticalAccelerationUnits"] == "m/s^2"
    assert settings["ParkingKalmanReset"] == "rising edge" and not settings["WatchdogDisabled"]
else:
    assert build["Step"] == .01 and settings["AcceptsSFIH182"] and settings["BaudRate"] == 921600
assert settings["RadioChannel"] == 3
for item in build["Binaries"]:
    file = root / item["File"]
    assert digest(file) == item["SHA256"] and file.stat().st_size == item["Bytes"]
app, bootloader, partitions = [root / item["File"] for item in build["Binaries"]]
assert app.stat().st_size <= 0x140000
devices = [p for p in list_ports.comports() if p.device == args.port
           and (p.serial_number or "").upper() == mac]
assert len(devices) == 1, "Selected port does not match the configured device."
runner = root / "tools/run_esptool.py"
assert (root / "tools/esptool.exe").is_file()
tag = datetime.now().strftime("%Y%m%d_%H%M%S")
backup = root / "backups" / f"{Path(model_name).stem}_{args.port}_before_horizontal_{tag}.bin"
backup.parent.mkdir(exist_ok=True)
assert not backup.exists()


def run(label, *arguments):
    subprocess.run([sys.executable, str(runner), label, "--chip", "esp32s3", "--port", args.port,
                    "--baud", "460800", *arguments], check=True)


label = f"horizontal_{args.device}"
# Retain and verify the full installed app before any write. Compare fixed regions.
run(label + "_backup", "--after", "no_reset", "read_flash", "0x10000", "0x140000", str(backup))
assert backup.stat().st_size == 0x140000
run(label + "_before_verify", "--before", "no_reset", "--after", "no_reset", "verify_flash",
    "0x10000", str(backup), "0x0", str(bootloader), "0x8000", str(partitions))
previous_app = root / "firmware/history/horizontal1801" / app.name
previous_matches = previous_app.is_file() and hashlib.sha256(
    backup.read_bytes()[:previous_app.stat().st_size]).hexdigest() == digest(previous_app)
print(f"INSTALLED_APP_BACKED_UP_AND_VERIFIED: prior stored image matches={previous_matches}", flush=True)
run(label + "_flash", "--before", "no_reset", "--after", "no_reset", "write_flash", "0x10000", str(app))
run(label + "_verify", "--before", "no_reset", "--after", "hard_reset", "verify_flash", "0x10000", str(app))
commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
report = {
    "recorded_at_utc": datetime.now(timezone.utc).isoformat(),
    "device": args.device, "port_at_flash": args.port, "mac": mac,
    "model": model_name, "model_sha256": digest(root / model_name), "source_commit_before_commit": commit,
    "firmware": app.relative_to(root).as_posix(), "firmware_sha256": digest(app),
    "firmware_bytes": app.stat().st_size, "radio_channel": settings["RadioChannel"],
    "app_offset": "0x10000", "written_regions": ["application"],
    "app_backup": backup.relative_to(root).as_posix(), "backup_bytes": backup.stat().st_size,
    "backup_sha256": digest(backup), "backup_read_and_verified_before_flash": True,
    "bootloader_and_partition_table_verified": True, "prior_stored_image_matched": previous_matches,
    "flash_completed": True, "flash_verified": True, "verification_result": "digest matched",
    "usb_only_confirmed_by_user": args.usb_only, "flight_commands_sent": False,
    "physical_flight_tested": False, "usb_startup_verified": False,
    "purpose": "USB-only incident diagnosis", "flight_release_approved": False,
    "build_record": "docs/horizontal_build.json", "settings": settings,
    "backup_log": f"logs/{label}_backup.log", "flash_log": f"logs/{label}_flash.log",
    "verify_log": f"logs/{label}_verify.log",
}
(root / f"docs/incident_{args.device}_deployment.json").write_text(
    json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"HORIZONTAL_{args.device.upper()}_FLASHED_AND_VERIFIED", flush=True)
