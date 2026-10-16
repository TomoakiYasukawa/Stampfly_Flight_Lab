param([switch]$Apply)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))))
$moves = [Collections.Generic.List[object]]::new()
function Plan-Move([string]$from, [string]$to) {
    $sourcePath = [IO.Path]::GetFullPath((Join-Path $projectRoot $from))
    $destinationPath = [IO.Path]::GetFullPath((Join-Path $projectRoot $to))
    foreach ($candidatePath in @($sourcePath, $destinationPath)) {
        if (-not $candidatePath.StartsWith($projectRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Move target is outside the project: $candidatePath"
        }
    }
    if (-not (Test-Path -LiteralPath $sourcePath)) { throw "Missing source: $from" }
    if (Test-Path -LiteralPath $destinationPath) { throw "Destination already exists: $to" }
    $moves.Add([pscustomobject]@{From=$from; To=$to; Source=$sourcePath; Destination=$destinationPath})
}
foreach ($packageName in @('+imu', '+official', '+reorg', '+stampfly')) { Plan-Move $packageName "code/$packageName" }
Plan-Move 'model_algorithms' 'code/model_algorithms'
Plan-Move 'models/StampFly_Official_FlightTest400.slx' 'archive/aircraft/StampFly_Official_FlightTest400.slx'
Plan-Move 'models/M5Stamp_IMU_Rx.slx' 'M5Stamp_IMU_Rx.slx'
Plan-Move 'models/StampFly_StudentBlocks.slx' 'libraries/StampFly_StudentBlocks.slx'
foreach ($modelFile in Get-ChildItem -LiteralPath (Join-Path $projectRoot 'models') -File) {
    if ($modelFile.BaseName -match 'Equivalence|^Phase') { Plan-Move "models/$($modelFile.Name)" "tests/models/$($modelFile.Name)" }
}
Plan-Move 'StampFlyIMUApp.xml' 'resources/app/StampFlyIMUApp.xml'
Plan-Move 'startup.m' 'config/startup.m'
Plan-Move 'setup_record.json' 'docs/history/setup_record.json'
Plan-Move 'partitions.csv' 'config/partitions.csv'
Plan-Move 'resources/project' 'archive/copied_project_metadata'
foreach ($sourceFile in Get-ChildItem -LiteralPath $projectRoot -File -Filter '*.m') {
    if ($sourceFile.Name -in @('StampFlyIMUApp.m','startup.m')) { continue }
    $category = 'model_edit'
    if ($sourceFile.BaseName -match '^(init_|setup_|ensure_|run_)') { $category = 'setup' }
    elseif ($sourceFile.BaseName -match '^build_(reorganized_flight_model|official_bench)$') { $category = 'build' }
    elseif ($sourceFile.BaseName -match '^(verify_|capture_)') { $category = 'verification' }
    elseif ($sourceFile.BaseName -match '^(analyze_|import_)') { $category = 'analysis' }
    Plan-Move $sourceFile.Name "scripts/$category/$($sourceFile.Name)"
}
foreach ($sourceFile in Get-ChildItem -LiteralPath $projectRoot -File) {
    if ($sourceFile.Extension -in @('.py','.ps1')) { Plan-Move $sourceFile.Name "tools/$($sourceFile.Name)" }
    elseif ($sourceFile.Extension -eq '.slxc') { Plan-Move $sourceFile.Name "build/legacy/cache/$($sourceFile.Name)" }
    elseif ($sourceFile.Extension -in @('.bin','.elf','.map')) { Plan-Move $sourceFile.Name "build/legacy/firmware/$($sourceFile.Name)" }
}
Plan-Move 'slprj' 'build/legacy/slprj'
foreach ($generatedFolder in Get-ChildItem -LiteralPath $projectRoot -Directory -Filter '*_ert_rtw') {
    Plan-Move $generatedFolder.Name "build/legacy/codegen/$($generatedFolder.Name)"
}
if ($Apply) {
    $manifestPath = Join-Path $projectRoot 'docs/history/project_file_moves.json'
    $moves | Select-Object From,To | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    foreach ($move in $moves) {
        $parentFolder = Split-Path -Parent $move.Destination
        if (-not (Test-Path -LiteralPath $parentFolder)) { New-Item -ItemType Directory -Path $parentFolder | Out-Null }
        Move-Item -LiteralPath $move.Source -Destination $move.Destination
    }
    Write-Output "Moved $($moves.Count) entries within $projectRoot"
} else {
    $moves | Select-Object From,To | Format-Table -AutoSize
    Write-Output "Planned $($moves.Count) moves. Run with -Apply after closing affected models."
}
