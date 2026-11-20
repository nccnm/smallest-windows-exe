# Median per program over reps, joining lead measure + R3 extra
function Get-Med($xs) { $s = @($xs | Where-Object { $_ -ne $null } | Sort-Object); if ($s.Count -eq 0) { return $null }; $s[[int][math]::Floor(($s.Count - 1) / 2)] }
$LeadAll = Get-Content "$PSScriptRoot\..\raw\r3-measure.jsonl" | ForEach-Object { $_ | ConvertFrom-Json }
$ExtraAll = Get-Content "$PSScriptRoot\..\raw\r3-extra.jsonl" | ForEach-Object { $_ | ConvertFrom-Json }
$names = $LeadAll | ForEach-Object { $_.label -replace '^r3-|-rep\d$', '' } | Sort-Object -Unique
$rows = foreach ($n in $names) {
  $l = $LeadAll | Where-Object { ($_.label -replace '^r3-|-rep\d$', '') -eq $n }
  $x = $ExtraAll | Where-Object { ($_.label -replace '^r3x-|-rep\d$', '') -eq $n }
  [pscustomobject]@{
    prog = $n; n = "$($l.Count)/$($x.Count)"; file_B = $l[0].file_bytes
    ws_kb = Get-Med $l.ws_kb_median; priv_kb = Get-Med $l.private_kb_median; peak_kb = Get-Med $l.peak_ws_kb
    wspriv_kb = Get-Med $x.ws_private_kb; wsshared_kb = Get-Med $x.ws_shared_kb
    cpu_ms20 = Get-Med $l.cpu_ms_in_window; ctx_s = Get-Med $x.ctx_per_s
    thr = Get-Med $l.threads; hnd = Get-Med $l.handles; mods = Get-Med $l.modules
    ch_ws = Get-Med $x.conhost_ws_kb; ch_wspriv = Get-Med $x.conhost_ws_private_kb; ch_commit = Get-Med $x.conhost_private_commit_kb; ch_thr = Get-Med $x.conhost_threads
    range_priv = "$(($l.private_kb_median | Measure-Object -Minimum).Minimum)-$(($l.private_kb_median | Measure-Object -Maximum).Maximum)"
  }
}
$rows | Select prog,n,file_B,ws_kb,priv_kb,wspriv_kb,wsshared_kb,thr,hnd,mods,cpu_ms20,ctx_s,ch_ws,ch_wspriv,ch_commit,ch_thr,range_priv | ConvertTo-Csv -NoTypeInformation
