# smallest-windows-exe

Source code, build scripts and measurement scripts for a study of the smallest Windows executable, and of how file size relates to RAM use. Every program shown in the accompanying video is here, including the Python script that writes the 268-byte exe, so you can rebuild each file and rerun each test.

Main findings, all measured on one Windows 11 x64 machine (build 26300):

- The smallest exe that Windows 11 x64 will run is 268 bytes. It only returns exit code 42. Files of 267 bytes and below, including the well-known 20, 97, 133 and 252-byte records, are rejected with error 216.
- A Hello World in C without the C runtime (CRT) is 768 bytes with MSVC; hand-built with NASM it is 584 bytes. Go gives 1,478,656 bytes, Rust with std 108,032 bytes.
- A smaller file does not mean less RAM. A minimal process costs about 460 KB of private memory whatever the file size; what raises RAM is the DLLs, windows and threads a program pulls in.

The full write-up is [report/report.en.md](report/report.en.md).

## Programs and sizes

Sizes are the ones measured in the video and the report. Rebuilding with the same tool versions gives the same sizes; the bytes differ only in timestamps (and in embedded build paths for Go).

### Hello World ladder (`hello/`)

All print `Hello, World!` (console) or show a `Hello, World!` message box (GUI, names with `gui`). Built by `hello/build.ps1` into `hello/out/`.

| File | Language | Toolchain | Key flags | Size (bytes) |
|---|---|---|---|---:|
| `go_default.exe` | Go | Go 1.27.1 | `go build` | 2,248,192 |
| `zig_debug.exe` | Zig | Zig 0.17.1 | `zig build-exe` (Debug) | 2,082,304 |
| `go_stripped.exe` | Go | Go 1.27.1 | `-ldflags='-s -w' -trimpath` | 1,478,656 |
| `upx_go_stripped.exe` | Go | UPX 5.1.1 | `upx --best --ultra-brute` | 517,632 |
| `zig_small.exe` | Zig | Zig 0.17.1 | `-O ReleaseSmall -fstrip -fsingle-threaded` | 483,840 |
| `rust_std_release.exe` | Rust | rustc 1.99.1 | `cargo build --release` | 130,560 |
| `msvc_crt_static.exe` | C | MSVC 14.51 | `cl /O1 /MT` (static CRT) | 111,104 |
| `rust_std_min.exe` | Rust | rustc 1.99.1 | profile `min`: `opt-level="z"`, LTO, 1 codegen unit, `panic="abort"`, strip | 108,032 |
| `msvc_gui_crt_static.exe` | C | MSVC 14.51 | `cl /O1 /MT`, MessageBox | 102,912 |
| `upx_rust_std_min.exe` | Rust | UPX 5.1.1 | `upx --best --ultra-brute` | 52,224 |
| `upx_msvc_crt_static.exe` | C | UPX 5.1.1 | `upx --best --ultra-brute` | 50,176 |
| `gcc_crt.exe`, `gcc_crt_static.exe` | C | GCC 16.1.0 (MSYS2 UCRT64) | `-Os -s` (with and without `-static`, same bytes) | 17,408 |
| `msvc_crt_dynamic.exe`, `msvc_gui_crt_dynamic.exe` | C | MSVC 14.51 | `cl /O1 /MD` (dynamic CRT) | 9,728 |
| `zig_bare_small.exe` | Zig | Zig 0.17.1 | kernel32 called directly, `ReleaseSmall` | 3,072 |
| `msvc_nocrt_plain.exe` | C | MSVC 14.51 | no CRT: `link /NODEFAULTLIB /ENTRY:start` | 2,560 |
| `fasm_cli.exe`, `fasm_gui.exe` | Assembly | FASM 1.73.35 | `format PE64` | 2,048 |
| `clang_nocrt.exe` | C | Clang 22.1.7 + LLD | `-nostdlib`, alignment 16 | 864 |
| `rust_nostd_min.exe` | Rust | rustc 1.99.1 | `#![no_std]`, linker flags in `build.rs` | 848 |
| `gcc_gui_nocrt.exe` | C | GCC 16.1.0 | `-nostdlib -mwindows`, alignment 16 | 816 |
| `gcc_nocrt.exe` | C | GCC 16.1.0 | `-nostdlib`, alignment 16 | 800 |
| `msvc_gui_nocrt_tuned.exe` | C | MSVC 14.51 | no CRT + tuned linker flags, MessageBox | 784 |
| `msvc_nocrt_tuned.exe` | C | MSVC 14.51 | no CRT + `/ALIGN:16 /FILEALIGN:16 /MERGE:...` | 768 |
| `nasm_tiny64_gui.exe` | Assembly | NASM 3.01 | `nasm -f bin -DGUI`, PE written by hand | 588 |
| `nasm_tiny64_cli.exe` | Assembly | NASM 3.01 | `nasm -f bin`, PE written by hand | 584 |
| `crinkler_x86_cli.exe` | C (x86) | Crinkler 3.0b | `/TINYHEADER /TINYIMPORT /UNSAFEIMPORT` | 355 |
| `crinkler_x86_gui.exe` | C (x86) | Crinkler 3.0b | same, MessageBox | 351 |

The two Crinkler files are detected by Windows Defender as `Trojan:Win32/Crysant.RPS!MTB` and deleted within about a minute of being written. This is a false positive caused by the packer's fingerprint; the source is the same `c_nocrt.c` and `gui_nocrt.c` as the other C builds. The other 27 builds were scanned clean.

### Hand-made files

| File | Made by | Size (bytes) | Result on Windows 11 build 26300 |
|---|---|---:|---|
| `pe268/tiny268.exe` | `pe268/make268.py` (Python, no compiler) | 268 | runs, exit code 42 |
| `pe268/hello268.exe` | `pe268/make268hello.py`, or `nasm -f bin hello268.asm` (same bytes) | 268 | prints `Hello, World!` (not shown in the video) |
| `tiny-files/268.exe` | same bytes as `tiny268.exe` | 268 | runs, exit code 42 |
| `tiny-files/267.exe` | `268.exe` minus its last byte | 267 | rejected, error 216 |
| `tiny-files/252.exe` | `sweep2.build32(252)`, PE32 x86 | 252 | rejected, error 216 |
| `tiny-files/133.exe` | `sweep2.build32(133)` | 133 | rejected, error 216 |
| `tiny-files/97.exe` | `sweep2.build32(97)` | 97 | rejected, error 216 |
| `tiny-files/20.com` | `make20.py`, 16-bit DOS .COM | 20 | rejected ("Unsupported 16-Bit Application") |

### RAM programs (`ram/`, `crinkler-ram/`, `pulsar-mini/`)

| File (name in the video) | Source | Size (bytes) | What it shows |
|---|---|---:|---|
| `ram1-kernel32.exe` | `ram/a_sleep.c`, console | 2,560 | imports kernel32 only, `Sleep(INFINITE)`: about 460 KB private bytes |
| `ram2-user32.exe` | `ram/b_getmsg.c` | 2,560 | adds user32, waits in `GetMessage`, no window |
| `ram3-window.exe` | `ram/c_window.c` | 3,072 | one window: 26 DLLs after about 30 s |
| `ram4-window-noime.exe` | `ram/n_noime.c` | 3,072 | one window after `ImmDisableIME(-1)` |
| `crinkler-standard.exe` | `crinkler-ram/build.cmd` (`ram/a_sleep.c`, x86) | 435 | default Crinkler mode: about 514 MB private bytes |
| `pulsar-mini.exe` | `pulsar-mini/` | 7,984 | a taskbar CPU/RAM/network widget in C without the CRT |

Numbers stated in the video for these programs (one run each; the report has medians of repeated runs): ram1 to ram4 about 470, 900, 1,750 and 1,320 KB private bytes; pulsar-mini 1,380 KB.

Go, C and Zig are compared with the same Hello World builds as in the size table, not with special versions: `msvc_nocrt_tuned.exe` (768 bytes), `go_stripped.exe` (1,478,656 bytes) and `zig_small.exe` (483,840 bytes). Each runs to its end under `tools/runstat.exe`, which reports its peak private memory. The video shows C 432 KB, Go 12,072 KB (about 28 times more) and Zig 576 KB; see "Go, C and Zig" below.

`ram/hello_idle.c` and `ram/hello_idle.go` are variants that wait instead of exiting, for watching the process in Task Manager. They are not used in the video.

## Requirements

Tested on Windows 11 Pro x64 build 26300 with PowerShell 7. Older or newer Windows builds may behave differently, especially for the 268-byte floor and the 16-byte alignment builds.

| Tool | Version used | Used for | Where to get it |
|---|---|---|---|
| Visual Studio 2026 Community (VS 18), "Desktop development with C++" | MSVC 14.51, LINK 14.51.36260, Windows SDK 10.0.26100 | all C builds, `cl`, `link`, `rc`, `dumpbin` | visualstudio.microsoft.com |
| MSYS2 UCRT64 at `C:\msys64` | GCC 16.1.0, Clang 22.1.7 + LLD, NASM 3.01, UPX 5.1.1 | gcc/clang builds, NASM, UPX | msys2.org, then `pacman -S mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-clang mingw-w64-ucrt-x86_64-lld mingw-w64-ucrt-x86_64-nasm mingw-w64-ucrt-x86_64-upx` |
| Rust (rustup, MSVC target) | rustc 1.99.1 | `hello/rust`, `hello/rust_nostd` | rustup.rs |
| Go | go1.27.1 | `hello/hello.go`, `ram/hello_idle.go` | go.dev/dl |
| Zig | 0.17.1 | Zig builds | ziglang.org/download, `zig-x86_64-windows-0.17.1.zip` |
| FASM (flat assembler for Windows) | 1.73.35 | FASM builds | flatassembler.net, `fasmw17335.zip` |
| Crinkler | 3.0b | Crinkler builds | github.com/runestubbe/Crinkler (releases), `crinkler30b.zip` |
| Python | 3.14 | `make268.py`, tiny files, `pe-anatomy.py` | python.org |
| Pillow | 12.3.0 | `tools/make-hex-figure.py` only | `pip install pillow` |
| ImHex | 1.38.1 | viewing the files byte by byte (the figures use saved captures) | imhex.werwolv.net |

The build scripts expect Visual Studio at `C:\Program Files\Microsoft Visual Studio\18\Community` and MSYS2 at `C:\msys64`. If yours are elsewhere, edit the `$vcvars` / `vcvars64.bat` lines at the top of each script.

FASM, Zig and Crinkler are not on `PATH`; unzip them into `toolchains/` at the repo root (this folder is git-ignored):

```
toolchains/
  fasm/                          FASM.EXE and INCLUDE/ from fasmw17335.zip
  zig-x86_64-windows-0.17.1/     zig.exe and lib/
  crinkler/crinkler30b/Win64/    Crinkler.exe
```

## Repository layout

```
hello/          Hello World in C (CRT, no CRT, GUI), NASM, FASM, Go, Zig, Rust std and no_std; build.ps1
pe268/          make268.py (the 268-byte exe), make268hello.py and hello268.asm (268-byte Hello World)
tiny-files/     the 20/97/133/252/267/268-byte test files: generators, size sweeps, run-all.cmd
ram/            RAM and idle-CPU test programs (R3 measurements) and the video's RAM scene builds
crinkler-ram/   the 435-byte Crinkler program that uses about 514 MB of RAM, and its measurement
pulsar-mini/    the taskbar widget rewritten in C without the CRT (7,984 bytes)
tools/          runstat.c, measure-hello.ps1, measure-resident.ps1, pe-anatomy.py, make-hex-figure.py, imhex/ captures
report/         report.en.md, its figures (images/) and the raw result files it links (raw/)
```

## Build and rerun the tests

Run the commands below in PowerShell 7 from the repo root unless a `Set-Location` says otherwise.

### 1. The Hello World ladder

```powershell
pwsh -File hello\build.ps1          # builds the 29 files into hello\out and prints a size table
```

The step-by-step build shown in act 3 of the video, typed in a "Developer PowerShell for VS" in `hello\`:

```powershell
cl /nologo /O1 /MT c_crt.c                                    # 111,104 bytes, static CRT
cl /nologo /O1 /Os /GS- /Gs9999999 /Oi- /c c_nocrt.c
link /nologo /NODEFAULTLIB /ENTRY:start /SUBSYSTEM:CONSOLE c_nocrt.obj kernel32.lib        # c_nocrt.exe, 2,560 bytes
link /nologo /NODEFAULTLIB /ENTRY:start /SUBSYSTEM:CONSOLE /ALIGN:16 /FILEALIGN:16 /MERGE:.rdata=.text /MERGE:.pdata=.text /FIXED /EMITTOOLVERSIONINFO:NO /NOCOFFGRPINFO c_nocrt.obj kernel32.lib /OUT:c_tuned.exe   # 768 bytes
nasm -f bin -o nasm.exe tiny64.asm                            # 584 bytes
dumpbin /nologo /disasm c_nocrt.exe                           # the whole program: 60 bytes of machine code
Get-ChildItem *.exe | Sort-Object Length -Descending | Format-Table Name, Length
```

The linker prints warning LNK4108 for `/ALIGN:16`; the file still runs on the Windows 11 builds tested (26100, 26200, 26300).

### 2. The 268-byte exe and the 267-byte rejection

```powershell
Set-Location pe268
python make268.py                                             # writes tiny268.exe, 268 bytes
(Start-Process .\tiny268.exe -Wait -PassThru).ExitCode        # 42
$b = Get-Content tiny268.exe -AsByteStream -Raw
Set-Content tiny267.exe $b[0..266] -AsByteStream
(Get-Item tiny267.exe).Length                                 # 267
.\tiny267.exe                                                 # rejected before a process is created
```

From `cmd.exe`, `tiny267.exe` prints "This version of ... is not compatible with the version of Windows you're running" and `%errorlevel%` is 216. From PowerShell or Explorer, Windows shows an "Unsupported 16-Bit Application" box.

`python make268hello.py` writes `hello268.exe`, a 268-byte file that does print `Hello, World!` by finding `WriteFile` through the PEB; `nasm -f bin -o hello268_nasm.exe hello268.asm` produces the same bytes.

### 3. The old records: 20, 97, 133 and 252 bytes

```powershell
Set-Location tiny-files
python make-tiny-files.py     # writes 20.com, 97.exe, 133.exe, 252.exe, 267.exe, 268.exe
.\run-all.cmd                 # runs each one and prints the exit code (Windows may show a dialog for some)
python tinype64.py            # x64 sweep: 268 bytes, then 267 down to 100 bytes, plus header variants
python sweep2.py              # x64 268/267/266/264/260 and x86 252 down to 97 bytes
```

The sweeps write the test files into `tiny-files\bin\` and their results to `results_*.json`, with Windows error dialogs suppressed.

### 4. Antivirus scan (act 5)

Build `hello\` first, then scan the 27 non-Crinkler builds in one folder, as in the video:

```powershell
New-Item -ItemType Directory scan | Out-Null
Get-ChildItem hello\out\*.exe | Where-Object Name -notmatch 'crinkler' | Copy-Item -Destination scan
Set-Location scan
(Get-ChildItem *.exe).Count                                   # 27
& "$env:ProgramFiles\Windows Defender\MpCmdRun.exe" -Scan -ScanType 3 -File $PWD -DisableRemediation
```

The Crinkler builds, in `hello\`:

```powershell
Select-String -Path out\crinkler_cli.log -Pattern 'Final file size'                # 355
Test-Path out\crinkler_x86_cli.exe                                                  # False once Defender has removed it
Get-MpThreatDetection | Where-Object Resources -match 'crinkler_x86' | Format-Table InitialDetectionTime, ThreatID
Get-MpThreat -ThreatID 2147830182 | Format-Table ThreatName                         # Trojan:Win32/Crysant.RPS!MTB
```

Building the Crinkler files triggers a Defender detection on your machine. The detection is a false positive, but do not disable the antivirus to keep the files; the point of the test is what a normal machine does.

### 5. Crinkler's RAM cost

```powershell
Set-Location crinkler-ram
.\build.cmd                   # unpacked.exe 2,560 bytes, crinkler-standard.exe 435, crinkler-tinyheader.exe 378 (x86)
pwsh -File .\measure.ps1      # writes samples.md: Working Set and Private Bytes at 1, 5, 35 and 60 s, three runs
```

The 435-byte file holds about 526,536 KiB (514 MB) of private bytes at 60 s, because the default decompressor uses a 500 MB hash table. `crinkler-tinyheader.exe` is usually removed by Defender before it can be measured.

### 6. RAM: file size against what the program loads (act 6)

```powershell
pwsh -File ram\build-video.ps1   # builds ram\out\ram1-kernel32.exe ... ram4-window-noime.exe (and the hello_idle variants)
Set-Location ram\out
Start-Process .\ram1-kernel32.exe -NoNewWindow; 'ram2-user32', 'ram3-window', 'ram4-window-noime' | ForEach-Object { Start-Process ".\$_.exe" }
Get-Process ram* | Format-Table Name, @{n='PrivateKB'; e={$_.PrivateMemorySize64 / 1KB}}, @{n='DLLs'; e={$_.Modules.Count - 1}}, @{n='Threads'; e={$_.Threads.Count}}
Get-Process hello-*, ram* | Stop-Process
```

The window builds load the IME and text input DLLs about 30 seconds after start; measure after that to see the 26 DLLs.

#### Go, C and Zig

The same three Hello World builds as in the size table, each run to its end under `tools\runstat.exe`, which prints its peak private memory. In the video the files are copied as `hello-c.exe`, `hello-go.exe` and `hello-zig.exe`; the bytes are unchanged.

```powershell
cmd /c '"C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat" >nul && cd tools && cl /nologo /O1 runstat.c /link psapi.lib'
'msvc_nocrt_tuned.exe', 'go_stripped.exe', 'zig_small.exe' | ForEach-Object { $r = tools\runstat.exe "hello\out\$_" | ConvertFrom-Json; [pscustomobject]@{Name = $_; PeakPrivateKB = $r.peak_private_kb} } | Format-Table
```

In the video: C 432 KB, Go 12,072 KB, Zig 576 KB. The numbers move a little from run to run and from machine to machine.

Repeated measurements, as in the report:

```powershell
pwsh -File tools\measure-hello.ps1                     # every hello\out build, 7 runs each, writes raw\hello-measure.jsonl
pwsh -File tools\measure-resident.ps1 -Exe ram\out\ram1-kernel32.exe -Settle 5 -Window 20
cmd /c ram\build.bat; cmd /c ram\build2.bat; cmd /c ram\build3.bat; cmd /c ram\build4.bat; cmd /c ram\build5.bat
pwsh -File ram\run-all.ps1 -Rep 1; pwsh -File ram\run-all.ps1 -Rep 1 -Kind extra   # repeat with -Rep 2, 3
pwsh -File ram\summarize.ps1                           # medians per program from raw\r3-*.jsonl
```

Idle CPU (act 7). `ram\cyc.c` starts a program, waits, then reads its CPU cycle count over a window with `QueryProcessCycleTime`. It was built with MSYS2 GCC 16.1.0; the exact command was not recorded, `gcc -O2` works:

```powershell
Set-Location ram
gcc -O2 -o cyc.exe cyc.c
.\cyc.exe "$PWD\b_getmsg.exe" 5 20      # waits in GetMessage: "cycles":0 in 20 seconds
.\cyc.exe "$PWD\g_poll.exe" 5 20        # Sleep(1) loop: about 1.3 million cycles per second
pwsh -File .\r3-extra.ps1 -Exe .\g_poll.exe -Settle 5 -Window 20    # ctx_per_s: about 99 context switches per second
```

`a_sleep_gcc.exe` in the `run-all.ps1` list was also built with MinGW gcc and has no build script here; that entry fails and the others still run.

### 7. pulsar-mini (act 7)

```powershell
Set-Location pulsar-mini
.\build.ps1 -Target Pulsar    # out\pulsar-mini.exe, 7,984 bytes
.\out\pulsar-mini.exe         # right-click the widget on the taskbar to exit
Get-Process pulsar-mini | Format-Table Name, @{n='PrivateKB'; e={$_.PrivateMemorySize64 / 1KB}}
```

See [pulsar-mini/README.md](pulsar-mini/README.md) for the other build options and limits. The original Pulsar app it is compared with (3.95 MB file) is a separate project and is not included.

### 8. Figures

```powershell
python tools\pe-anatomy.py        # PE layout of the sample files, tools\out\pe-anatomy.json
python tools\make-hex-figure.py   # rebuilds report\images\06\ui-imhex-*.png from tools\imhex\ captures and the built exes
```

Both need `hello\` built and `pe268\tiny268.exe` written. `make-hex-figure.py` labels every field with values read from the exe files themselves; rebuilt with the tool versions above it reproduces the report's figures pixel for pixel. It also writes Vietnamese-labelled copies to `tools\imhex\vi\` (git-ignored).

## Paths in the report

The report was written in the original research folder. Its paths map to this repository as follows:

| Path in the report | Here |
|---|---|
| `poc/hello/` | `hello/` |
| `poc/pe268/` | `pe268/` |
| `poc/com20/`, `poc/thu-file-nho/` | `tiny-files/` |
| `poc/mini/` | `pulsar-mini/` |
| `scratch/01/` (size sweeps) | `tiny-files/tinype64.py`, `tiny-files/sweep2.py` |
| `scratch/03/` (RAM programs) | `ram/` |
| `build/runstat.c`, `build/measure-*.ps1`, `build/pe-anatomy.py`, `build/make-hex-figure.py` | `tools/` |
| `raw/imhex/` | `tools/imhex/` |
| `research_notes/`, other `raw/` files, `scratch/04/`, `scratch/windows-compat/` | not included |

The report's references to `research_notes/` (internal working notes, not published) are kept as plain text.

## Notes

- Every number was measured on one machine: Windows 11 Pro build 26300, x64. RAM numbers move a little from run to run.
- Builds with `/ALIGN:16` or hand-written headers rely on loader behaviour Microsoft does not document or promise.
- The 268-byte file has no sections, so the loader skips its import table; that is why it can only return an exit code.

## Credits

- [Crinkler](https://github.com/runestubbe/Crinkler) by Aske Simon Christensen and Rune Stubbe (zlib license). The memory quote in the video is from its issue #25.
- [flat assembler (FASM)](https://flatassembler.net) by Tomasz Grysztar.
- [NASM](https://www.nasm.us), [UPX](https://upx.github.io), [MSYS2](https://www.msys2.org), [GCC](https://gcc.gnu.org), [LLVM/Clang/LLD](https://llvm.org).
- [Zig](https://ziglang.org), [Go](https://go.dev), [Rust](https://www.rust-lang.org), [Python](https://www.python.org), [Pillow](https://python-pillow.org).
- [ImHex](https://github.com/WerWolv/ImHex) by WerWolv, used for the byte-level figures.
- Microsoft Visual Studio, MSVC and the Windows SDK.
- [Pulsar](https://github.com/oMaN-Rod/Pulsar) by oMaN-Rod and [Wireless Device Battery Monitor](https://github.com/krisgfx9/Wireless-Device-Battery-Monitor) by krisgfx9, the original apps that `pulsar-mini/` re-implements in part. No code was taken from them.
- The 20-byte DOS Hello World follows a 2011 gnostice article; the 97, 133 and 252-byte layouts follow published tiny-PE records (see the report's sources).

## License

MIT, see [LICENSE](LICENSE). Third-party tools are not included and keep their own licenses.
