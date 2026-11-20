param([int]$Rep = 1, [ValidateSet('lead','extra')][string]$Kind = 'lead')
$d = $PSScriptRoot
$raw = Join-Path $PSScriptRoot '..\raw'; New-Item -ItemType Directory -Force $raw | Out-Null
$names = 'a_sleep_con','a_sleep_gui','a_sleep_gcc','b_getmsg','c_window','f_button_v5','f_button_v6','d_crt_md','d_crt_mt','d_crtgui_md','e_pad','e_padtouch','e_bss','g_poll','h_timer','i_eco','j_poll_tbp'
foreach ($n in $names) {
  if ($Kind -eq 'lead') {
    pwsh -File "$PSScriptRoot\..\tools\measure-resident.ps1" -Exe "$d\$n.exe" -Settle 5 -Window 20 -Label "r3-$n-rep$Rep" -Out "$raw\r3-measure.jsonl"
  } else {
    pwsh -File "$d\r3-extra.ps1" -Exe "$d\$n.exe" -Settle 5 -Window 20 -Label "r3x-$n-rep$Rep" -Out "$raw\r3-extra.jsonl"
  }
}
