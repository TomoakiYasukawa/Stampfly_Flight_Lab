"""List connected serial ports for the setup PowerShell script."""
import json
from serial.tools import list_ports

print(json.dumps([{'port': p.device, 'serial': p.serial_number} for p in list_ports.comports()]))
