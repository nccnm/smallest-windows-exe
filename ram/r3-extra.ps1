# Supplemental measurement for R3: private working set (Task Manager "Memory" column),
# shared WS, commit, context switches (wakeups) per second, thread count, conhost child cost.
param([Parameter(Mandatory)][string]$Exe, [int]$Settle = 5, [int]$Window = 20, [string]$Label = '', [string]$Out = '')
$ErrorActionPreference = 'Stop'
$full = (Resolve-Path $Exe).Path
$p = Start-Process -FilePath $full -PassThru
Start-Sleep -Seconds $Settle
function Get-Ctx([int]$procId) {
  $t = Get-CimInstance Win32_PerfRawData_PerfProc_Thread -Filter "IDProcess=$procId"
  ($t | Measure-Object -Property ContextSwitchesPersec -Sum).Sum
}
$c0 = Get-Ctx $p.Id; $p.Refresh(); $cpu0 = $p.TotalProcessorTime.TotalMilliseconds
Start-Sleep -Seconds $Window
$c1 = Get-Ctx $p.Id; $p.Refresh(); $cpu1 = $p.TotalProcessorTime.TotalMilliseconds
$perf = Get-CimInstance Win32_PerfRawData_PerfProc_Process -Filter "IDProcess=$($p.Id)"
$child = Get-CimInstance Win32_Process -Filter "ParentProcessId=$($p.Id)" | Where-Object Name -in 'conhost.exe','OpenConsole.exe'
$cperf = if ($child) { Get-CimInstance Win32_PerfRawData_PerfProc_Process -Filter "IDProcess=$($child[0].ProcessId)" } else { $null }
$mods = -1; try { $mods = $p.Modules.Count } catch {}
$r = [ordered]@{
  label = if ($Label) { $Label } else { [IO.Path]::GetFileNameWithoutExtension($full) }
  file_bytes = (Get-Item $full).Length
  ws_kb = [math]::Round($p.WorkingSet64 / 1KB)
  ws_private_kb = [math]::Round($perf.WorkingSetPrivate / 1KB)
  ws_shared_kb = [math]::Round(($p.WorkingSet64 - $perf.WorkingSetPrivate) / 1KB)
  private_commit_kb = [math]::Round($p.PrivateMemorySize64 / 1KB)
  virtual_mb = [math]::Round($p.VirtualMemorySize64 / 1MB)
  threads = $p.Threads.Count
  ctx_per_s = [math]::Round(($c1 - $c0) / $Window, 1)
  cpu_ms = [math]::Round($cpu1 - $cpu0, 1)
  window_s = $Window
  modules = $mods
  conhost_ws_kb = if ($cperf) { [math]::Round($cperf.WorkingSet / 1KB) } else { $null }
  conhost_ws_private_kb = if ($cperf) { [math]::Round($cperf.WorkingSetPrivate / 1KB) } else { $null }
  conhost_private_commit_kb = if ($cperf) { [math]::Round($cperf.PrivateBytes / 1KB) } else { $null }
  conhost_threads = if ($cperf) { $cperf.ThreadCount } else { $null }
  measured_at = (Get-Date).ToString('s')
}
Stop-Process -Id $p.Id -Force
$json = $r | ConvertTo-Json -Compress
if ($Out) { Add-Content -Path $Out -Value $json }
$json
