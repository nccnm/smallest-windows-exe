# Builds the programs of the RAM scene in the video into ram\out, under the names shown on screen:
#   ram1-kernel32.exe      a_sleep.c, console   (Sleep(INFINITE), imports kernel32 only)
#   ram2-user32.exe        b_getmsg.c           (adds user32, waits in GetMessage, no window)
#   ram3-window.exe        c_window.c           (one window)
#   ram4-window-noime.exe  n_noime.c            (one window, ImmDisableIME(-1) first)
#   hello-c.exe            hello_idle.c         (no-CRT Hello World that stays alive, 784 bytes)
#   hello-go.exe           hello_idle.go        (Go Hello World that stays alive, 1,484,288 bytes with go1.27.1)
# The first four come from build.bat and build5.bat (the R3 measurement builds); this script only adds the
# two hello_idle builds and copies the files. Requires VS 18 (MSVC x64) and Go.
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$out = Join-Path $here 'out'; New-Item -ItemType Directory -Force $out | Out-Null
$vcvars = 'C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat'
function Invoke-Cmd([string]$line) {
    & cmd.exe /d /c $line
    if ($LASTEXITCODE -ne 0) { throw "Build failed: $line" }
}
Invoke-Cmd "`"$here\build.bat`""
Invoke-Cmd "`"$here\build5.bat`""
# Same no-CRT flags as the 768-byte tuned Hello World in hello\build.ps1
$cl = '/nologo /O1 /Os /GS- /Gs9999999 /Oi- /c'
$link = '/nologo /NODEFAULTLIB /ENTRY:start /DYNAMICBASE:NO /FIXED /MANIFEST:NO /DEBUG:NONE /EMITTOOLVERSIONINFO:NO /NOCOFFGRPINFO /MERGE:.rdata=.text /MERGE:.pdata=.text /ALIGN:16 /FILEALIGN:16 /OPT:REF /OPT:ICF /SECTION:.text,ERW'
Invoke-Cmd "`"$vcvars`" >nul && cd /d `"$here`" && cl $cl hello_idle.c /Fo:out\hello_idle.obj && link $link /SUBSYSTEM:CONSOLE out\hello_idle.obj kernel32.lib /OUT:out\hello-c.exe"
Push-Location $here
$env:GOOS = 'windows'; $env:GOARCH = 'amd64'
go build -ldflags='-s -w' -o out\hello-go.exe hello_idle.go
if ($LASTEXITCODE -ne 0) { throw 'go build failed' }
Pop-Location
Copy-Item "$here\a_sleep_con.exe" "$out\ram1-kernel32.exe" -Force
Copy-Item "$here\b_getmsg.exe" "$out\ram2-user32.exe" -Force
Copy-Item "$here\c_window.exe" "$out\ram3-window.exe" -Force
Copy-Item "$here\n_noime.exe" "$out\ram4-window-noime.exe" -Force
Get-ChildItem $out -Filter *.exe | Sort-Object Name | Format-Table Name, Length -AutoSize
