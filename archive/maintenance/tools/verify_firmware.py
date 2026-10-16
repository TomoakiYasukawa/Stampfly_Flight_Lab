"""Verify immutable flash regions; allow runtime NVS updates."""
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[3]
port, name, label = sys.argv[1:]
source = (root / 'official_sources' / name).read_bytes()
out = root / 'official_sources' / 'verification'
out.mkdir(exist_ok=True)
app = out / (name + '.app.bin')
app.write_bytes(source[65536:])
runner = root / 'tools' / 'run_esptool.py'
base = [sys.executable, str(runner)]
common = ['--chip', 'esp32s3', '--port', port, '--baud', '460800']
subprocess.run(base + [label + '_app_verify'] + common + ['verify_flash', '0x10000', str(app)], check=True)
header = root / 'logs' / (label + '_header.bin')
subprocess.run(base + [label + '_header_read'] + common + ['--after', 'no_reset', 'read_flash', '0', '0x10000', str(header)], check=True)
actual = header.read_bytes()
try:
    if actual[:32768] != source[:32768]:
        raise RuntimeError('Bootloader differs from the official download')
    if actual[32768:36864] != source[32768:36864]:
        raise RuntimeError('Partition table differs from the official download')
    print('Official application, bootloader and partition table verified.', flush=True)
finally:
    subprocess.run(base + [label + '_restart'] + common + ['--before', 'no_reset', 'run'], check=True)
