# Builds the programs of the RAM ladder scene in the video into ram\out, under the names shown on screen:
#   ram1-kernel32.exe      a_sleep.c, console   (Sleep(INFINITE), imports kernel32 only)
#   ram2-user32.exe        b_getmsg.c           (adds user32, waits in GetMessage, no window)
#   ram3-window.exe        c_window.c           (one window)
#   ram4-window-noime.exe  n_noime.c            (one window, ImmDisableIME(-1) first)
# They come from build.bat and build5.bat (the R3 measurement builds); this script runs those and copies
# the files. Requires VS 18 (MSVC x64).
# The Go, C and Zig comparison of the same scene uses the Hello World builds themselves: compare.ps1.
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$out = Join-Path $here 'out'; New-Item -ItemType Directory -Force $out | Out-Null
function Invoke-Cmd([string]$line) {
    & cmd.exe /d /c $line
    if ($LASTEXITCODE -ne 0) { throw "Build failed: $line" }
}
Invoke-Cmd "`"$here\build.bat`""
Invoke-Cmd "`"$here\build5.bat`""
Copy-Item "$here\a_sleep_con.exe" "$out\ram1-kernel32.exe" -Force
Copy-Item "$here\b_getmsg.exe" "$out\ram2-user32.exe" -Force
Copy-Item "$here\c_window.exe" "$out\ram3-window.exe" -Force
Copy-Item "$here\n_noime.exe" "$out\ram4-window-noime.exe" -Force
Get-ChildItem $out -Filter *.exe | Sort-Object Name | Format-Table Name, Length -AutoSize
