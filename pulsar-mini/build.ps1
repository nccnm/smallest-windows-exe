param([switch]$Standard, [switch]$Clang, [switch]$FullUI, [switch]$BatteryOnly, [switch]$Static, [switch]$Diagnostics, [switch]$DiskGpu,
      [switch]$NetTable, [ValidateSet('All','Pulsar','Battery')][string]$Target = 'All')
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$out = Join-Path $here 'out'
New-Item -ItemType Directory -Path $out -Force | Out-Null
$vcvars = 'C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat'
$compile = '/nologo /W4 /O1 /Os /GL /Gw /Gy /GS- /Zl /Oi- /c'
$link = '/nologo /LTCG /NODEFAULTLIB /ENTRY:start /SUBSYSTEM:WINDOWS /MANIFEST:NO /INCREMENTAL:NO /OPT:REF /OPT:ICF /DEBUG:NONE /NXCOMPAT /EMITTOOLVERSIONINFO:NO /NOCOFFGRPINFO'
$suffix = ''
$compiler = 'cl'
if ($Clang) {
    $compiler = '"C:\msys64\ucrt64\bin\clang-cl.exe"'
    $compile = '/nologo /W4 /O1 /GS- /Zl /Oi- /clang:-Oz /c'
    $suffix = '-clang'
}
if ($FullUI) { $compile += ' /DFULL_UI'; $suffix += '-full' }
if ($Diagnostics) { $compile += ' /DP1_DIAGNOSTICS'; $suffix += '-p1' }
if ($Static) { $compile += ' /DSTATIC_SAMPLE'; $suffix += '-static' }
if ($NetTable) { $compile += ' /DNET_TABLE'; $suffix += '-table' }
if ($BatteryOnly) { $Target = 'Battery' }
if ($DiskGpu -and ($Static -or $Target -eq 'Battery')) { throw '-DiskGpu requires a non-static Pulsar target.' }
if ($Standard) { $link += ' /DYNAMICBASE /FIXED:NO'; $suffix += '-standard' }
else {
    # A valid 72-byte DOS MZ stub, exiting with code 1 on DOS. LINK writes e_lfanew.
    $dosStub = New-Object byte[] 72
    $dosStub[0] = 0x4d; $dosStub[1] = 0x5a; $dosStub[2] = 72; $dosStub[4] = 1
    $dosStub[8] = 4; $dosStub[12] = 0xff; $dosStub[13] = 0xff; $dosStub[16] = 0x10
    $dosStub[24] = 0x40; $dosStub[60] = 72
    $dosStub[64] = 0xb8; $dosStub[65] = 1; $dosStub[66] = 0x4c; $dosStub[67] = 0xcd; $dosStub[68] = 0x21
    [IO.File]::WriteAllBytes((Join-Path $out 'tiny-dos.bin'), $dosStub)
    $link += ' /DYNAMICBASE:NO /FIXED /ALIGN:16 /FILEALIGN:16 /STUB:out\tiny-dos.bin /MERGE:.rdata=.text /MERGE:.pdata=.text /SECTION:.text,ERW'
}
function Invoke-Build([string]$line) {
    & cmd.exe /d /c "`"$vcvars`" >nul && cd /d `"$here`" && $line"
    if ($LASTEXITCODE -ne 0) { throw "Build failed: $LASTEXITCODE" }
}
Invoke-Build 'rc /nologo /fo out\app.res app.rc'
Invoke-Build "$compiler $($compile.Replace(' /GL ', ' ')) runtime.c /Fo:out\runtime.obj"
if ($Target -ne 'Battery') {
    $pulsarCompile = $compile
    $pulsarSuffix = $suffix
    $pulsarExtra = ''
    if ($DiskGpu) {
        $pulsarCompile += ' /DDISK_GPU'
        $pulsarSuffix += '-disk-gpu'
        Invoke-Build "$compiler $pulsarCompile metrics.c /Fo:out\metrics.obj"
        $pulsarExtra = 'out\metrics.obj pdh.lib'
    }
    Invoke-Build "$compiler $pulsarCompile ui.c /Fo:out\pulsar.obj"
    Invoke-Build "link $link out\pulsar.obj out\runtime.obj out\app.res kernel32.lib user32.lib gdi32.lib advapi32.lib imm32.lib iphlpapi.lib ntdll.lib $pulsarExtra /OUT:out\pulsar-mini$pulsarSuffix.exe"
}
if ($Target -ne 'Pulsar' -and -not $Static -and (Test-Path (Join-Path $here 'battery.c'))) {
    Invoke-Build "$compiler $compile battery.c /Fo:out\battery.obj"
    Invoke-Build "$compiler $compile /DBATTERY_LIST_LIBRARY battery-cli.c /Fo:out\battery-list-lib.obj"
    Invoke-Build "$compiler $compile /DBATTERY_ONLY ui.c /Fo:out\battery-ui.obj"
    Invoke-Build "link $link out\battery-ui.obj out\battery.obj out\battery-list-lib.obj out\runtime.obj out\app.res kernel32.lib user32.lib gdi32.lib advapi32.lib imm32.lib cfgmgr32.lib hid.lib /OUT:out\battery-mini$suffix.exe"
    Invoke-Build "$compiler $compile battery-cli.c /Fo:out\battery-cli.obj"
    $console = $link.Replace('/SUBSYSTEM:WINDOWS','/SUBSYSTEM:CONSOLE')
    Invoke-Build "link $console out\battery-cli.obj out\battery.obj out\runtime.obj kernel32.lib cfgmgr32.lib hid.lib /OUT:out\battery-list$suffix.exe"
}
Get-ChildItem -LiteralPath $out -Filter '*.exe' | Select-Object Name,Length
