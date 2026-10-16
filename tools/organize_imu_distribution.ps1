param([switch]$Apply)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
if (Test-Path -LiteralPath (Join-Path $projectRoot 'docs/imu_distribution_moves.json')) {
    throw 'This one-time distribution migration is already complete. See docs/imu_distribution_moves.json.'
}
$moves = [Collections.Generic.List[object]]::new()
function Plan-Move([string]$from, [string]$to) {
    $sourcePath = [IO.Path]::GetFullPath((Join-Path $projectRoot $from))
    $destinationPath = [IO.Path]::GetFullPath((Join-Path $projectRoot $to))
    foreach ($candidatePath in @($sourcePath, $destinationPath)) {
        if (-not $candidatePath.StartsWith($projectRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Move target is outside the project: $candidatePath"
        }
    }
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { throw "Missing source: $from" }
    if (Test-Path -LiteralPath $destinationPath) { throw "Destination exists: $to" }
    $moves.Add([pscustomobject]@{From=$from; To=$to; Source=$sourcePath; Destination=$destinationPath;
        SHA256=(Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash.ToLowerInvariant()})
}
$currentDocs = @('setup.md','dependencies.md','imu_flight_model.md','logging_extensions.md','THIRD_PARTY_NOTICES.md',
    'imu_cleanup_structure.json','imu_function_documentation.json','imu_block_documentation.json',
    'imu_cleanup_layout.json','imu_cleanup_verification.json')
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $projectRoot 'docs') -File) {
    if ($file.Name -notin $currentDocs) { Plan-Move "docs/$($file.Name)" "docs/history/$($file.Name)" }
}
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $projectRoot 'docs/images') -File) {
    Plan-Move "docs/images/$($file.Name)" "docs/history/images/$($file.Name)"
}
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $projectRoot 'archive') -File -Filter '*.slx') {
    Plan-Move "archive/$($file.Name)" "archive/snapshots/$($file.Name)"
}
$activeEdits=@('annotate_imu_blocks.m','annotate_imu_functions.m','cleanup_imu_model.m',
    'finalize_imu_cleanup.m','layout_imu_cleanup.m','imu_block_documentation.json','imu_function_documentation.json')
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $projectRoot 'scripts/model_edit') -File) {
    if ($file.Name -notin $activeEdits) { Plan-Move "scripts/model_edit/$($file.Name)" "archive/maintenance/scripts/model_edit/$($file.Name)" }
}
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $projectRoot 'scripts/build') -File) {
    Plan-Move "scripts/build/$($file.Name)" "archive/maintenance/scripts/build/$($file.Name)"
}
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $projectRoot 'scripts/verification') -File) {
    if ($file.Name -ne 'verify_imu_cleanup.m') { Plan-Move "scripts/verification/$($file.Name)" "archive/maintenance/scripts/verification/$($file.Name)" }
}
foreach ($name in @('register_imu_readability400.m','register_kf_flight400.m','init_kf_flight.m','init_official_replay.m')) {
    Plan-Move "scripts/setup/$name" "archive/maintenance/scripts/setup/$name"
}
$activeTools=@('capture_imu_startup.py','list_devices.py','run_esptool.py','serial_monitor.py',
    'update_block_help.py','organize_imu_distribution.ps1')
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $projectRoot 'tools') -File) {
    if ($file.Extension -in @('.py','.ps1') -and $file.Name -notin $activeTools) {
        Plan-Move "tools/$($file.Name)" "archive/maintenance/tools/$($file.Name)"
    }
}
foreach ($name in @('basic400','current','imu400','imu400_readability','logging400','pid_experiment','previous_successful')) {
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $projectRoot "firmware/$name") -File) {
        Plan-Move "firmware/$name/$($file.Name)" "firmware/history/$name/$($file.Name)"
    }
}
if ($Apply) {
    foreach ($move in $moves) {
        $parentFolder = Split-Path -Parent $move.Destination
        if (-not (Test-Path -LiteralPath $parentFolder)) { New-Item -ItemType Directory -Path $parentFolder | Out-Null }
        Move-Item -LiteralPath $move.Source -Destination $move.Destination
        $afterHash=(Get-FileHash -LiteralPath $move.Destination -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($afterHash -ne $move.SHA256) { throw "Content changed while moving: $($move.From)" }
    }
    $manifestPath=Join-Path $projectRoot 'docs/imu_distribution_moves.json'
    $moves | Select-Object From,To,SHA256 | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    Write-Output "Moved $($moves.Count) files. Every file hash is unchanged."
} else {
    $moves | Group-Object {($_.To -split '/')[0..2] -join '/'} | Select-Object Count,Name | Format-Table -AutoSize
    Write-Output "Planned $($moves.Count) file moves."
}
