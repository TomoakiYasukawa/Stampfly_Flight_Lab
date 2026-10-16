import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[3]
items = [
    ('StampFly', 'COM4', '70:AF:09:DF:A6:C4', 'stampfly', 'stampfly_firmware_v1.1.0_20240812.bin'),
    ('JoyStick', 'COM6', '48:CA:43:B6:5B:30', 'joystick', 'StampFlyController_V1.2.0_20260610.bin'),
]
report = {'date': '2026-10-14', 'devices': [], 'pairing_status': 'awaiting screen verification', 'flight_test': 'not performed'}
record_path = root / 'docs' / 'history' / 'setup_record.json'
if record_path.exists():
    previous = json.loads(record_path.read_text(encoding='utf-8'))
    for key in ('pairing_status', 'telemetry_status', 'flight_test', 'user_observations'):
        if key in previous:
            report[key] = previous[key]
for device, port, mac, stem, name in items:
    source = (root / 'official_sources' / name).read_bytes()
    actual = (root / 'logs' / f'{stem}_header_after_boot.bin').read_bytes()
    diff = [i for i, (a, b) in enumerate(zip(source[:65536], actual)) if a != b]
    entry = {
        'device': device, 'port': port, 'mac': mac, 'flash_size': 8388608,
        'firmware': name, 'firmware_sha256': hashlib.sha256(source).hexdigest(),
        'bootloader_matches': actual[:32768] == source[:32768],
        'partition_table_matches': actual[32768:36864] == source[32768:36864],
        'app_matches': '-- verify OK (digest matched)' in (root / 'logs' / f'{stem}_app_verify.log').read_text(encoding='utf-8'),
        'changed_header_sectors': sorted(set(f'0x{i // 4096 * 4096:04X}' for i in diff)),
        'changed_header_byte_count': len(diff),
    }
    backup = root / 'backups' / f'{device}_{port}_before_official_20261014.bin'
    entry['backup'] = str(backup.relative_to(root))
    entry['backup_size'] = backup.stat().st_size
    entry['backup_sha256'] = hashlib.sha256(backup.read_bytes()).hexdigest()
    report['devices'].append(entry)
    print(json.dumps(entry, indent=2))
record_path.write_text(json.dumps(report, indent=2), encoding='utf-8')
