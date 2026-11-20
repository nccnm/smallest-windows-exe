$ErrorActionPreference='Stop'
$base=$PSScriptRoot
$out=Join-Path $base 'samples.md'
'# Crinkler RAM - Sleep(INFINITE) program, x86','','| Run | File | SHA-256 at start | Seconds | Working Set KiB | Private Bytes KiB | Virtual Size KiB | State |','|---:|---|---|---:|---:|---:|---:|---|' | Set-Content -LiteralPath $out
foreach($run in 1..3){
 $live=@()
 try {
  foreach($file in 'unpacked.exe','crinkler-standard.exe','crinkler-tinyheader.exe'){
   $path=Join-Path $base $file
   $hash='-'
   try {
    $hash=(Get-FileHash -LiteralPath $path).Hash
    $p=Start-Process -FilePath $path -PassThru -WindowStyle Hidden
    $live+=@{p=$p;clock=[Diagnostics.Stopwatch]::StartNew();f=$file;hash=$hash}
   } catch {
    "| $run | $file | $hash | - | - | - | - | failed to start: $($_.Exception.Message.Replace('|','/')) |" | Add-Content -LiteralPath $out
   }
  }
  foreach($s in 1,5,35,60) {
   foreach($entry in $live){
    $left=[Math]::Max(0,[int](1000*$s-$entry.clock.Elapsed.TotalMilliseconds))
    if($left){Start-Sleep -Milliseconds $left}
    $p=$entry.p
    $p.Refresh()
    if($p.HasExited){
      "| $run | $($entry.f) | $($entry.hash) | $s | - | - | - | exited: $($p.ExitCode) |" | Add-Content -LiteralPath $out
    } else {
      '| {0} | {1} | {2} | {3:F3} | {4} | {5} | {6} | waiting |' -f $run,$entry.f,$entry.hash,$entry.clock.Elapsed.TotalSeconds,($p.WorkingSet64/1KB),($p.PrivateMemorySize64/1KB),($p.VirtualMemorySize64/1KB) | Add-Content -LiteralPath $out
    }
   }
  }
 } finally {
   foreach($entry in $live){
    $p=$entry.p
    if(!$p.HasExited){$p.Kill();$p.WaitForExit()}
    $p.Dispose()
   }
 }
}
