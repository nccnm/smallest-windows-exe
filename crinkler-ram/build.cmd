@echo off
call "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars32.bat" >nul || exit /b 1
cd /d "%~dp0" || exit /b 1
cl /nologo /O1 /Os /GS- /Gs9999999 /Oi- /c ..\ram\a_sleep.c /Foresident.obj || exit /b 1
link /nologo /NODEFAULTLIB /ENTRY:start /SUBSYSTEM:WINDOWS /OUT:unpacked.exe resident.obj kernel32.lib || exit /b 1
set "crinkler=..\toolchains\crinkler\crinkler30b\Win64\Crinkler.exe"
"%crinkler%" /NOINITIALIZERS /ENTRY:start /SUBSYSTEM:WINDOWS /OUT:crinkler-standard.exe resident.obj kernel32.lib user32.lib >standard.txt
echo standard link exit=%errorlevel%
"%crinkler%" /NOINITIALIZERS /ENTRY:start /SUBSYSTEM:WINDOWS /TINYHEADER /OUT:crinkler-tinyheader.exe resident.obj kernel32.lib user32.lib >tinyheader.txt
echo tinyheader link exit=%errorlevel%

