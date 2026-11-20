@echo off
call "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat" >nul 2>nul
cd /d "%~dp0"
cl /nologo /O1 /GS- /c j_poll_tbp.c && link /nologo /NODEFAULTLIB /ENTRY:start /MANIFEST:NO /SUBSYSTEM:WINDOWS j_poll_tbp.obj kernel32.lib winmm.lib /OUT:j_poll_tbp.exe
cl /nologo /O1 k_res.c /Fek_res.exe >nul
