# Re-run (sequentially) any label/rep missing from the jsonl files (lost to concurrent-write collisions)
$d = $PSScriptRoot
$names = 'a_sleep_con','a_sleep_gui','a_sleep_gcc','b_getmsg','c_window','f_button_v5','f_button_v6','d_crt_md','d_crt_mt','d_crtgui_md','e_pad','e_padtouch','e_bss','g_poll','h_timer','i_eco','j_poll_tbp','m_dyn'
$raw = Join-Path $PSScriptRoot '..\raw'; New-Item -ItemType Directory -Force $raw | Out-Null
$lf = "$raw\r3-measure.jsonl"; $xf = "$raw\r3-extra.jsonl"
$have = @{}
foreach ($f in $lf, $xf) { if (Test-Path $f) { Get-Content $f | ForEach-Object { try { $have[($_ | ConvertFrom-Json).label] = 1 } catch {} } } }
foreach ($n in $names) { foreach ($r in 1..3) {
  if (-not $have["r3-$n-rep$r"]) { pwsh -File "$PSScriptRoot\..\tools\measure-resident.ps1" -Exe "$d\$n.exe" -Settle 5 -Window 20 -Label "r3-$n-rep$r" -Out $lf }
  if (-not $have["r3x-$n-rep$r"]) { pwsh -File "$d\r3-extra.ps1" -Exe "$d\$n.exe" -Settle 5 -Window 20 -Label "r3x-$n-rep$r" -Out $xf }
} }
