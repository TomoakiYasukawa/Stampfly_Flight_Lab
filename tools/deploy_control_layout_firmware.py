"""Back up and deploy the built control-layout firmware on the known StampFly."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

from serial.tools import list_ports

sys.stdout.reconfigure(encoding="utf-8")
parser = argparse.ArgumentParser()
parser.add_argument("--usb-only", action="store_true", required=True)
parser.add_argument("--port", default="COM4")
parser.add_argument("--expected-mac", required=True)
parser.add_argument("--firmware-sha256", required=True)
parser.add_argument("--model-sha256", required=True)
parser.add_argument("--source-commit", required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
model = root / "StampFly_Official_FlightTest400.slx"
firmware = root / "build/model_reorganization/StampFly_Official_FlightTest400.bin"

def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

if sha256(firmware) != args.firmware_sha256.lower():
    raise RuntimeError("Built firmware hash changed; refusing to flash.")
if sha256(model) != args.model_sha256.lower():
    raise RuntimeError("Saved model changed after build; refusing to flash.")
build = json.loads((root / "docs/reorganized_flight_build.json").read_text(encoding="utf-8"))
equivalence = json.loads((root / "docs/control_layout_verification.json").read_text(encoding="utf-8"))
if not (build["BuildPassed"] and build["Step"] == 0.0025
        and build["PWMHz"] == 150000 and build["PWMBits"] == 8
        and build["StateflowChartCount"] == 4 and build["EmbeddedMATLABFunctionCount"] == 0
        and equivalence["Passed"] and equivalence["TotalSamples"] == 36000):
    raise RuntimeError("Build or equivalence checks are incomplete.")
devices = [p for p in list_ports.comports()
           if p.device == args.port and (p.serial_number or "").upper() == args.expected_mac.upper()]
if len(devices) != 1:
    raise RuntimeError("Selected port does not match the expected StampFly.")
tag = datetime.now().strftime("%Y%m%d_%H%M%S")
backup = root / "backups" / f"StampFly_{args.port}_before_control_layout_{tag}_app0.bin"
backup.parent.mkdir(exist_ok=True)
report = {
    "recorded_at_utc": datetime.now(timezone.utc).isoformat(),
    "device": {"port_at_flash": args.port, "mac": args.expected_mac.upper()},
    "model": str(model.relative_to(root)), "model_sha256": args.model_sha256.lower(),
    "source_commit": args.source_commit,
    "build_firmware": str(firmware.relative_to(root)),
    "firmware": "firmware/current/StampFly_Official_FlightTest400.bin",
    "firmware_sha256": args.firmware_sha256.lower(),
    "app_offset": "0x10000", "app_backup": str(backup.relative_to(root)),
    "motor_output_enabled": True, "usb_only_confirmed_by_user": True,
    "flash_verified": False, "equivalence_samples": 36000, "equivalence_outputs": 15,
    "logger_port_untouched": "COM9", "physical_flight_verified": False,
    "physical_timing_measured": False,
}
runner = root / "tools/run_esptool.py"

def run(label, *arguments):
    subprocess.run([sys.executable, str(runner), label, "--chip", "esp32s3", "--port", args.port,
                    "--baud", "460800", *arguments], check=True)

run("control_layout_app_backup", "--after", "no_reset", "read_flash", "0x10000", "0x140000", str(backup))
if backup.stat().st_size != 0x140000:
    raise RuntimeError("Incomplete app backup; refusing to flash.")
run("control_layout_flight_flash", "--before", "no_reset", "--after", "no_reset", "write_flash", "0x10000", str(firmware))
run("control_layout_flight_verify", "--before", "no_reset", "--after", "hard_reset", "verify_flash", "0x10000", str(firmware))

# Only promote the new distributable image after verification succeeds.
current = root / "firmware/current"
history = root / "firmware/history" / f"before_control_layout_{tag}"
history.mkdir(parents=True)
for old in current.glob("StampFly_Official_FlightTest400*.bin"):
    shutil.copy2(old, history / old.name)
old_record = root / "docs/reorganized_flight_deployment.json"
if old_record.is_file():
    shutil.copy2(old_record, history / "deployment.json")
for suffix in (".bin", ".bootloader.bin", ".partitions.bin"):
    source = firmware.parent / ("StampFly_Official_FlightTest400" + suffix)
    if source.is_file():
        shutil.copy2(source, current / source.name)
report.update({"flash_verified": True, "verification_result": "digest matched",
               "flash_log": "logs/control_layout_flight_flash.log",
               "verify_log": "logs/control_layout_flight_verify.log",
               "previous_firmware_folder": str(history.relative_to(root))})
text = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
(root / "docs/control_layout_flight_deployment.json").write_text(text, encoding="utf-8")
old_record.write_text(text, encoding="utf-8")
print("CONTROL_LAYOUT_FIRMWARE_FLASHED_AND_VERIFIED", flush=True)
