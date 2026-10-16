"""Reset USB-connected bench firmware and immediately capture boot diagnostics."""
import re
import subprocess
import sys
import time
from pathlib import Path
import serial

root = Path(__file__).resolve().parents[3]
subprocess.run([str(root/'tools'/'esptool.exe'), '--chip', 'esp32s3',
                '--port', 'COM4', '--after', 'watchdog_reset', 'chip_id'],
               check=True, stdout=subprocess.DEVNULL)
link = serial.Serial()
link.port, link.baudrate, link.timeout = 'COM4', 921600, 0.05
link.dtr, link.rts = False, False
link.open()
link.dtr = True
data = bytearray()
end = time.monotonic()+30
while time.monotonic() < end:
    data.extend(link.read(4096))
link.close()
(root/'logs'/'bench400_boot.bin').write_bytes(data)
for line in re.findall(rb'SF(?:TOF|TIMING)[^\r\n]*', data):
    print(line.decode(errors='replace'))
print('NACKs', data.count(b'NACK'))
