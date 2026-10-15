param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('StampFly', 'JoyStick')]
    [string]$Device,
    [string]$Port,
    [switch]$UsbOnly
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $UsbOnly) {
    throw 'Remove the StampFly battery and propellers, then rerun with -UsbOnly.'
}

$config = @{
    StampFly = @{
        Mac = '70:AF:09:DF:A6:C4'
        Firmware = 'stampfly_firmware_v1.1.0_20240812.bin'
        Hash = '0138cc333d05790f8804fabae223f4c7eb40d162ad1d23d8c8daead6412d4359'
    }
    JoyStick = @{
        Mac = '48:CA:43:B6:5B:30'
        Firmware = 'StampFlyController_V1.2.0_20260610.bin'
        Hash = '8235beaecf1b0703584f603f4e3bb952c95620a85e34bc13a230b06d16204886'
    }
}
$target = $config[$Device]
$portsJson = & python (Join-Path $projectRoot 'tools/list_devices.py')
if ($LASTEXITCODE -ne 0) { throw 'Unable to enumerate serial ports.' }
$matches = @((ConvertFrom-Json $portsJson) | Where-Object { $_.serial -eq $target.Mac })
if ($matches.Count -ne 1) { throw "Expected one connected $Device with MAC $($target.Mac)." }
$detectedPort = $matches[0].port
if ($Port -and $Port -ne $detectedPort) { throw "Wrong device at $Port. $Device is at $detectedPort." }
$Port = $detectedPort
$firmwarePath = Join-Path $projectRoot "official_sources/$($target.Firmware)"
if ((Get-FileHash -LiteralPath $firmwarePath -Algorithm SHA256).Hash -ne $target.Hash) {
    throw 'Firmware SHA256 does not match the verified official download.'
}

$runner = Join-Path $projectRoot 'tools/run_esptool.py'
$backupDir = Join-Path $projectRoot 'backups'
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
$timeTag = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupPath = Join-Path $backupDir "${Device}_${Port}_${timeTag}.bin"
Write-Host "Backing up $Device ($Port) to $backupPath"
& python $runner "${Device}_backup_$timeTag" --chip esp32s3 --port $Port --baud 460800 --after no_reset read_flash 0x0 0x800000 $backupPath
if ($LASTEXITCODE -ne 0) { throw 'Backup failed; firmware was not written.' }
if ((Get-Item -LiteralPath $backupPath).Length -ne 8388608) { throw 'Incomplete backup; firmware was not written.' }
& python $runner "${Device}_flash_$timeTag" --chip esp32s3 --port $Port --baud 460800 --before no_reset write_flash 0x0 $firmwarePath
if ($LASTEXITCODE -ne 0) { throw 'Flashing failed. Inspect the saved log before retrying.' }
& python (Join-Path $projectRoot 'tools/verify_firmware.py') $Port $target.Firmware "${Device}_verify_$timeTag"
if ($LASTEXITCODE -ne 0) { throw 'Flash verification failed.' }
Write-Host "$Device official firmware written and verified. Restart the device and check pairing."
