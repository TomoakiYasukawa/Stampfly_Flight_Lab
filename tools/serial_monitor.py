"""Receive USB serial logs; never transmit flight commands."""
import argparse
import concurrent.futures
import re
import sys
import time
from pathlib import Path

import serial

sys.stdout.reconfigure(encoding='utf-8')
parser = argparse.ArgumentParser()
parser.add_argument('ports', nargs='+')
parser.add_argument('--seconds', type=float, default=15)
parser.add_argument('--label', default='serial')
parser.add_argument('--reset', action='store_true', help='Reset via the USB Serial/JTAG RTS line before monitoring')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
(root / 'logs').mkdir(exist_ok=True)

def monitor(port):
    link = serial.Serial()
    link.port, link.baudrate, link.timeout = port, 115200, 0.1
    link.dtr, link.rts = False, False
    link.open()
    if args.reset:
        link.rts = True
        time.sleep(0.2)
        link.rts = False
    link.dtr = True
    data = bytearray()
    end = time.monotonic() + args.seconds
    try:
        while time.monotonic() < end:
            data.extend(link.read(4096))
    finally:
        link.close()
    raw = root / 'logs' / f'{args.label}_{port}.bin'
    raw.write_bytes(data)
    text = data.decode('utf-8', errors='replace')
    (root / 'logs' / f'{args.label}_{port}.txt').write_text(text, encoding='utf-8')
    print(f'{port}: {len(data)} bytes; log={raw}', flush=True)
    if len(data) < 20000:
        print(text, flush=True)
    else:
        lines = text.splitlines()
        unique = list(dict.fromkeys(lines))
        print('\n'.join(unique[:100]), flush=True)
        print(f'Total lines={len(lines)}; unique={len(unique)}', flush=True)

with concurrent.futures.ThreadPoolExecutor(max_workers=len(args.ports)) as pool:
    for result in pool.map(monitor, args.ports):
        pass
