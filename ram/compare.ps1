# The Go, C and Zig comparison of the RAM scene in the video, with the same Hello World builds as in the
# size table (no special versions): each one is run to its end under tools\runstat.exe, which prints its
# peak private memory.
#   hello-c.exe    = hello\out\msvc_nocrt_tuned.exe   768 bytes, the C build from act 3
#   hello-go.exe   = hello\out\go_stripped.exe        1,478,656 bytes
#   hello-zig.exe  = hello\out\zig_small.exe          483,840 bytes
# Build hello\ first (hello\build.ps1). runstat.exe is built here if it is missing (VS 18, MSVC x64).
# The files are copied to ram\compare\ under the names shown in the video; the bytes are unchanged.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
$dir = Join-Path $PSScriptRoot 'compare'; New-Item -ItemType Directory -Force $dir | Out-Null
$runstat = Join-Path $root 'tools\runstat.exe'
if (-not (Test-Path $runstat)) {
    $vcvars = 'C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat'
    & cmd.exe /d /c "`"$vcvars`" >nul && cd /d `"$root\tools`" && cl /nologo /O1 runstat.c /link psapi.lib"
    if ($LASTEXITCODE -ne 0) { throw 'runstat build failed' }
}
$files = [ordered]@{ 'hello-c.exe' = 'msvc_nocrt_tuned.exe'; 'hello-go.exe' = 'go_stripped.exe'; 'hello-zig.exe' = 'zig_small.exe' }
foreach ($k in $files.Keys) {
    $src = Join-Path $root "hello\out\$($files[$k])"
    if (-not (Test-Path $src)) { throw "$src is missing: run hello\build.ps1 first" }
    Copy-Item $src (Join-Path $dir $k) -Force
}
Copy-Item $runstat (Join-Path $dir 'runstat.exe') -Force
Push-Location $dir
try {
    # the commands typed in the video
    .\hello-c.exe; .\hello-go.exe
    Get-ChildItem hello-*.exe | Format-Table Name, Length
    'hello-c.exe', 'hello-go.exe', 'hello-zig.exe' | ForEach-Object { $r = .\runstat.exe ".\$_" | ConvertFrom-Json; [pscustomobject]@{Name = $_; PeakPrivateKB = $r.peak_private_kb} } | Format-Table
} finally {
    Pop-Location
}
