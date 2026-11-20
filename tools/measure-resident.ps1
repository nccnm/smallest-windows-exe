# Measure a long-running (resident) program: launch it, let it settle, then sample memory and CPU.
# Usage: pwsh -File measure-resident.ps1 -Exe <path> [-ArgList <string>] [-Settle 10] [-Window 60] [-Label name] [-Out results.jsonl]
# Reports: file size, working set, private bytes (commit), peak WS, CPU ms consumed during the window,
# threads, handles, modules, cycle count and raw per-thread context-switch deltas.
# Cycle counts are NOT converted to milliseconds. Context switches are NOT wakeups.
param(
  [Parameter(Mandatory)] [string] $Exe,
  [string] $ArgList = '',
  [int] $Settle = 10,
  [int] $Window = 60,
  [string] $Label = '',
  [string] $Out = '',
  [switch] $KeepRunning
)
$ErrorActionPreference = 'Stop'
if ($Settle -lt 0 -or $Window -lt 1) { throw 'Settle must be >= 0 and Window >= 1' }
if (-not ('ResidentCycles' -as [type])) {
  Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
public static class ResidentCycles {
  [DllImport("kernel32.dll", SetLastError=true)]
  static extern bool QueryProcessCycleTime(IntPtr process, out ulong cycles);
  public static ulong Read(IntPtr handle) {
    ulong cycles;
    if (!QueryProcessCycleTime(handle, out cycles)) throw new Win32Exception(Marshal.GetLastWin32Error());
    return cycles;
  }
}
'@
}
function Get-ThreadSwitches([int]$ProcessId) {
  $result = @{}
  $stamp = $null; $frequency = $null
  foreach ($t in Get-CimInstance Win32_PerfRawData_PerfProc_Thread -Filter "IDProcess=$ProcessId") {
    $result[[string]$t.IDThread] = [uint64]$t.ContextSwitchesPersec
    $stamp = [uint64]$t.Timestamp_PerfTime; $frequency = [uint64]$t.Frequency_PerfTime
  }
  return @{ threads = $result; stamp = $stamp; frequency = $frequency }
}
$full = (Resolve-Path $Exe).Path
$psi = @{ FilePath = $full; PassThru = $true }
if ($ArgList) { $psi.ArgumentList = $ArgList }
$p = Start-Process @psi
$lifetime = [Diagnostics.Stopwatch]::StartNew()
try {
Start-Sleep -Seconds $Settle
$p.Refresh()
if ($p.HasExited) { throw "process exited early with code $($p.ExitCode)" }
$ctxError = $null
$ctx0 = @{}; $ctx1 = @{}
try { $snapshot0 = Get-ThreadSwitches $p.Id; $ctx0 = $snapshot0.threads } catch { $ctxError = $_.Exception.Message }
$ctxWatch = [Diagnostics.Stopwatch]::StartNew()
$cycles0 = [ResidentCycles]::Read($p.Handle)
$watch = [Diagnostics.Stopwatch]::StartNew()
$cpu0 = $p.TotalProcessorTime.TotalMilliseconds
$ws = @(); $pv = @()
$at60 = $null
for ($i = 0; $i -lt $Window; $i++) {
  Start-Sleep -Seconds 1
  $p.Refresh()
  if ($p.HasExited) { throw "process exited during window" }
  $ws += $p.WorkingSet64; $pv += $p.PrivateMemorySize64
  if (-not $at60 -and $lifetime.Elapsed.TotalSeconds -ge 60) {
    $at60 = @{ elapsed_s = [math]::Round($lifetime.Elapsed.TotalSeconds,3); ws_kib = $p.WorkingSet64/1KB; private_kib = $p.PrivateMemorySize64/1KB }
  }
}
$p.Refresh()
$cpu1 = $p.TotalProcessorTime.TotalMilliseconds
$cycles1 = [ResidentCycles]::Read($p.Handle)
$watch.Stop()
try { $snapshot1 = Get-ThreadSwitches $p.Id; $ctx1 = $snapshot1.threads } catch { $ctxError = $_.Exception.Message }
$ctxWatch.Stop()
$contextSeconds = $ctxWatch.Elapsed.TotalSeconds
if ($snapshot0 -and $snapshot1 -and $snapshot0.frequency -gt 0 -and $snapshot1.stamp -gt $snapshot0.stamp) {
  $contextSeconds = ($snapshot1.stamp - $snapshot0.stamp)/[double]$snapshot0.frequency
}
$ctxDelta = [uint64]0; $exited = 0; $newThreads = 0
foreach ($key in $ctx0.Keys) { if (-not $ctx1.ContainsKey($key)) { $exited++ } }
foreach ($key in $ctx1.Keys) {
  if ($ctx0.ContainsKey($key)) {
    if ($ctx1[$key] -ge $ctx0[$key]) { $ctxDelta += $ctx1[$key] - $ctx0[$key] }
    else { $ctxError = 'A thread counter decreased or its ID was reused' }
  } else { $ctxDelta += $ctx1[$key]; $newThreads++ }
}
$privateWs = try {
  $perf = Get-CimInstance Win32_PerfRawData_PerfProc_Process -Filter "IDProcess=$($p.Id)"
  if ($perf) { [math]::Round($perf.WorkingSetPrivate / 1KB) } else { $null }
} catch { $null }
$mods = try { $p.Modules.Count } catch { -1 }
$r = [ordered]@{
  label        = if ($Label) { $Label } else { [IO.Path]::GetFileNameWithoutExtension($full) }
  exe          = $full
  file_bytes   = (Get-Item $full).Length
  ws_kb_median = [math]::Round((($ws | Sort-Object)[[int]($ws.Count/2)]) / 1KB)
  private_kb_median = [math]::Round((($pv | Sort-Object)[[int]($pv.Count/2)]) / 1KB)
  peak_ws_kb   = [math]::Round($p.PeakWorkingSet64 / 1KB)
  cpu_ms_in_window = [math]::Round($cpu1 - $cpu0, 1)
  cpu_cycles_in_window = $cycles1 - $cycles0
  cpu_cycles_per_s = [math]::Round(($cycles1 - $cycles0)/$watch.Elapsed.TotalSeconds,1)
  measured_window_s = [math]::Round($watch.Elapsed.TotalSeconds,3)
  context_switches = if ($ctxError -or -not $ctx0.Count -or -not $ctx1.Count) { $null } else { $ctxDelta }
  context_switches_per_s = if ($ctxError -or -not $ctx0.Count -or -not $ctx1.Count) { $null } else { [math]::Round($ctxDelta/$contextSeconds,3) }
  context_window_s = [math]::Round($contextSeconds,3)
  context_exited_threads = $exited
  context_new_threads = $newThreads
  context_note = if ($ctxError) { $ctxError } elseif ($exited) { 'Lower bound: exited threads are absent from the final snapshot; also may miss threads born and exited between snapshots; not wakeups' } else { 'Live-thread snapshot deltas; may miss threads born and exited between snapshots; not a wakeup count' }
  ws_private_kib_final = $privateWs
  memory_at_60 = $at60
  settle_s = $Settle
  thread_context_deltas = @($ctx1.Keys | Sort-Object | ForEach-Object {
    @{ thread_id = $_; switches = if ($ctx0.ContainsKey($_) -and $ctx1[$_] -ge $ctx0[$_]) { $ctx1[$_] - $ctx0[$_] } else { $ctx1[$_] } }
  })
  window_s     = $Window
  threads      = $p.Threads.Count
  handles      = $p.HandleCount
  modules      = $mods
  os           = [Environment]::OSVersion.VersionString
  measured_at  = (Get-Date).ToString('s')
  sha256 = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
}
$json = $r | ConvertTo-Json -Compress
if ($Out) { Add-Content -Path $Out -Value $json }
$json
} finally {
  if (-not $KeepRunning -and -not $p.HasExited) { Stop-Process -Id $p.Id -Force }
  $p.Dispose()
}
