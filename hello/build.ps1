# Build the Hello World size ladder. Outputs go to hello/out/. Prints a size table.
# Requires: VS 18 (MSVC), MSYS2 ucrt64 (gcc, clang, lld, nasm, upx), toolchains/ (fasm, zig, crinkler), Rust, Go.
$ErrorActionPreference = 'Continue'
$here = $PSScriptRoot
$root = Resolve-Path "$here\.."
$out = "$here\out"; New-Item -ItemType Directory -Force $out | Out-Null
$vcvars = 'C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat'
$vcvars32 = 'C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars32.bat'
$ucrt = 'C:\msys64\ucrt64\bin'
$fasm = "$root\toolchains\fasm"
$zig = "$root\toolchains\zig-x86_64-windows-0.17.1\zig.exe"
$crinkler = "$root\toolchains\crinkler\crinkler30b\Win64\Crinkler.exe"

function Msvc([string]$cmd, [string]$bat = $vcvars) {
  cmd /c "`"$bat`" >nul && cd /d `"$here`" && $cmd" 2>&1 | Where-Object { $_ -notmatch '^(c_|gui_)\w+\.c$' }
}
# Shared MSVC no-CRT flags. /GS- removes the security cookie (needs CRT), /Gs9999999 avoids __chkstk probes.
$clNoCrt = '/nologo /O1 /Os /GS- /Gs9999999 /Oi- /c'
$lkNoCrt = '/nologo /NODEFAULTLIB /ENTRY:start /DYNAMICBASE:NO /FIXED /MANIFEST:NO /DEBUG:NONE /EMITTOOLVERSIONINFO:NO /NOCOFFGRPINFO /MERGE:.rdata=.text /MERGE:.pdata=.text /ALIGN:16 /FILEALIGN:16 /OPT:REF /OPT:ICF /SECTION:.text,ERW'

Write-Host '== MSVC'
Msvc "cl /nologo /O1 /MT c_crt.c /Fe:out\msvc_crt_static.exe /Fo:out\ >nul"
Msvc "cl /nologo /O1 /MD c_crt.c /Fe:out\msvc_crt_dynamic.exe /Fo:out\ >nul"
Msvc "cl /nologo /O1 /MD gui_crt.c /Fe:out\msvc_gui_crt_dynamic.exe /Fo:out\ /link user32.lib >nul"
Msvc "cl /nologo /O1 /MT gui_crt.c /Fe:out\msvc_gui_crt_static.exe /Fo:out\ /link user32.lib >nul"
Msvc "cl $clNoCrt c_nocrt.c /Fo:out\c_nocrt.obj && link /nologo /NODEFAULTLIB /ENTRY:start /SUBSYSTEM:CONSOLE out\c_nocrt.obj kernel32.lib /OUT:out\msvc_nocrt_plain.exe"
Msvc "link $lkNoCrt /SUBSYSTEM:CONSOLE out\c_nocrt.obj kernel32.lib /OUT:out\msvc_nocrt_tuned.exe"
Msvc "cl $clNoCrt gui_nocrt.c /Fo:out\gui_nocrt.obj && link $lkNoCrt /SUBSYSTEM:WINDOWS out\gui_nocrt.obj kernel32.lib user32.lib /OUT:out\msvc_gui_nocrt_tuned.exe"

Write-Host '== MinGW gcc / clang (ucrt64)'
$env:Path = "$ucrt;$env:Path"
Push-Location $here
gcc -Os -s c_crt.c -o out\gcc_crt.exe
gcc -Os -s -static c_crt.c -o out\gcc_crt_static.exe
gcc -Os -s -nostdlib -fno-asynchronous-unwind-tables -fno-ident -e start '-Wl,--gc-sections,--file-alignment=16,--section-alignment=16,--disable-dynamicbase,--disable-reloc-section,--no-insert-timestamp' c_nocrt.c -lkernel32 -o out\gcc_nocrt.exe
gcc -Os -s -nostdlib -mwindows -fno-asynchronous-unwind-tables -fno-ident -e start '-Wl,--gc-sections,--file-alignment=16,--section-alignment=16,--disable-dynamicbase,--disable-reloc-section,--no-insert-timestamp' gui_nocrt.c -lkernel32 -luser32 -o out\gcc_gui_nocrt.exe
clang -Os -s -nostdlib -fuse-ld=lld -fno-asynchronous-unwind-tables '-Wl,-e,start' '-Wl,--file-alignment=16,--section-alignment=16' c_nocrt.c -lkernel32 -o out\clang_nocrt.exe

Write-Host '== NASM hand-built PE / FASM'
nasm -f bin -o out\nasm_tiny64_cli.exe tiny64.asm
nasm -f bin -DGUI -o out\nasm_tiny64_gui.exe tiny64.asm
$env:INCLUDE = "$fasm\INCLUDE"
& "$fasm\FASM.EXE" hello.fasm out\fasm_cli.exe | Out-Null
& "$fasm\FASM.EXE" gui.fasm out\fasm_gui.exe | Out-Null

Write-Host '== Zig'
& $zig build-exe hello.zig -O ReleaseSmall -fstrip -fsingle-threaded '-femit-bin=out\zig_small.exe' 2>&1
& $zig build-exe hello.zig '-femit-bin=out\zig_debug.exe' 2>&1
& $zig build-exe hello_zig_bare.zig -O ReleaseSmall -fstrip -fsingle-threaded '-femit-bin=out\zig_bare_small.exe' 2>&1
Remove-Item out\*.pdb -ErrorAction SilentlyContinue

Write-Host '== Go'
$env:GOOS = 'windows'; $env:GOARCH = 'amd64'
go build -o out\go_default.exe hello.go
go build -ldflags='-s -w' -trimpath -o out\go_stripped.exe hello.go

Write-Host '== Rust'
Push-Location "$here\rust"
cargo build --release -q 2>&1
Copy-Item target\release\hello_std.exe ..\out\rust_std_release.exe -Force
cargo build --profile min -q 2>&1
Copy-Item target\min\hello_std.exe ..\out\rust_std_min.exe -Force
Pop-Location
Push-Location "$here\rust_nostd"
cargo build --release -q 2>&1
Copy-Item target\release\hello_nostd.exe ..\out\rust_nostd_min.exe -Force
Pop-Location

Write-Host '== Crinkler (x86 output) and UPX'
Msvc "cl $clNoCrt c_nocrt.c /Fo:out\c_nocrt32.obj && `"$crinkler`" /NOINITIALIZERS /ENTRY:start /SUBSYSTEM:CONSOLE /UNSAFEIMPORT /TINYHEADER /TINYIMPORT /OUT:out\crinkler_x86_cli.exe out\c_nocrt32.obj kernel32.lib >out\crinkler_cli.log" $vcvars32
Msvc "cl $clNoCrt gui_nocrt.c /Fo:out\gui_nocrt32.obj && `"$crinkler`" /NOINITIALIZERS /ENTRY:start /SUBSYSTEM:WINDOWS /UNSAFEIMPORT /TINYHEADER /TINYIMPORT /OUT:out\crinkler_x86_gui.exe out\gui_nocrt32.obj kernel32.lib user32.lib >out\crinkler_gui.log" $vcvars32
foreach ($n in 'msvc_crt_static', 'go_stripped', 'rust_std_min') {
  upx --best --ultra-brute -q -o "out\upx_$n.exe" "out\$n.exe" 2>&1 | Out-Null
}
Pop-Location

Get-ChildItem $out -Filter *.exe | Sort-Object Length | Select-Object Name, Length | Format-Table -AutoSize
