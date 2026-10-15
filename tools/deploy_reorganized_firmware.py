"""Deploy the verified app image on the identified USB-only StampFly."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import sys

from serial.tools import list_ports

sys.stdout.reconfigure(encoding='utf-8')
parser = argparse.ArgumentParser()
parser.add_argument('--usb-only', action='store_true', required=True)
parser.add_argument('--port', default='COM4')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
firmware = root/'firmware/current/StampFly_Official_FlightTest400.bin'
expected_sha = '4f8fde9013cd943aab884ade2f9f7e2532b55e086b510bb405d92e823b0190b2'
actual_sha = hashlib.sha256(firmware.read_bytes()).hexdigest()
if actual_sha != expected_sha:
    raise RuntimeError('Firmware differs from the verified build.')
device = [p for p in list_ports.comports() if p.device == args.port and (p.serial_number or '').upper() == '70:AF:09:DF:A6:C4']
if len(device) != 1:
    raise RuntimeError('The selected port is not the expected StampFly.')
tag = datetime.now().strftime('%Y%m%d_%H%M%S')
backup = root/'backups'/f'StampFly_{args.port}_before_reorganized_{tag}_app0.bin'
backup.parent.mkdir(exist_ok=True)
report = {'recorded_at_utc':datetime.now(timezone.utc).isoformat(), 'device':{'port_at_flash':args.port,'mac':'70:AF:09:DF:A6:C4'},
          'model':'StampFly_Official_FlightTest400.slx', 'firmware':str(firmware.relative_to(root)),
          'firmware_sha256':actual_sha, 'app_offset':'0x10000', 'app_backup':str(backup.relative_to(root)),
          'motor_output_enabled':True, 'usb_only_confirmed_by_user':True, 'flash_verified':False,
          'equivalence_samples':36000, 'equivalence_outputs':15, 'logger_port_untouched':'COM9'}
runner = root/'tools/run_esptool.py'
def run(label, *arguments):
    subprocess.run([sys.executable,str(runner),label,'--chip','esp32s3','--port',args.port,'--baud','460800',*arguments],check=True)
run('reorganized_app_backup','--after','no_reset','read_flash','0x10000','0x140000',str(backup))
if backup.stat().st_size != 0x140000:
    raise RuntimeError('Incomplete app backup; refusing to flash.')
run('reorganized_flight_flash','--before','no_reset','--after','no_reset','write_flash','0x10000',str(firmware))
run('reorganized_flight_verify','--before','no_reset','--after','hard_reset','verify_flash','0x10000',str(firmware))
report['flash_verified'] = True
report['flash_log'] = 'logs/reorganized_flight_flash.log'
report['verify_log'] = 'logs/reorganized_flight_verify.log'
(root/'docs/reorganized_flight_deployment.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Reorganized StampFly firmware flashed and verified. COM9 was not opened.',flush=True)
