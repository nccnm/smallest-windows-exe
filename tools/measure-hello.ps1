# Measure every Hello World build in hello/out.
# CLI exes: run 7 times through runstat.exe (peak working set / peak private / CPU / wall), keep the median.
# GUI exes (name contains "gui"): the MessageBox stays open, so sample it as a resident process.
param([int]$Runs = 7, [string]$Out = "$PSScriptRoot\..\raw\hello-measure.jsonl")
$ErrorActionPreference = 'Stop'
$dir = Resolve-Path "$PSScriptRoot\..\hello\out"
$runstat = "$PSScriptRoot\runstat.exe"
if (Test-Path $Out) { Remove-Item $Out }
New-Item -ItemType Directory -Force (Split-Path $Out) | Out-Null
function Median($xs) { $s = $xs | Sort-Object; $s[[int][math]::Floor($s.Count / 2)] }
foreach ($e in Get-ChildItem $dir -Filter *.exe | Sort-Object Length) {
  if ($e.Name -match 'gui') {
    $j = pwsh -NoProfile -File "$PSScriptRoot\measure-resident.ps1" -Exe $e.FullName -Settle 3 -Window 10 | ConvertFrom-Json
    $r = [ordered]@{ name = $e.BaseName; kind = 'gui'; file_bytes = $e.Length; ws_kb = $j.ws_kb_median; private_kb = $j.private_kb_median; peak_ws_kb = $j.peak_ws_kb; threads = $j.threads; modules = $j.modules; cpu_ms_10s = $j.cpu_ms_in_window }
  } else {
    $rs = 1..$Runs | ForEach-Object { & $runstat $e.FullName | ConvertFrom-Json }
    $r = [ordered]@{ name = $e.BaseName; kind = 'cli'; file_bytes = $e.Length
      peak_ws_kb = Median $rs.peak_ws_kb; peak_private_kb = Median $rs.peak_private_kb
      page_faults = Median $rs.page_faults; cpu_us = Median ($rs | ForEach-Object { $_.cpu_kernel_us + $_.cpu_user_us }); wall_us = Median $rs.wall_us; runs = $Runs }
  }
  $line = $r | ConvertTo-Json -Compress; Add-Content $Out $line; $line
}
