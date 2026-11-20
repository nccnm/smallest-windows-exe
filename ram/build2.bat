@echo off
call "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat" >nul 2>nul
cd /d "%~dp0"
set CF=/nologo /O1 /GS- /Gs999999 /c
set LF=/nologo /NODEFAULTLIB /ENTRY:start /MANIFEST:NO /OPT:REF /OPT:ICF
cl %CF% e_padtouch.c && link %LF% /SUBSYSTEM:WINDOWS e_padtouch.obj kernel32.lib /OUT:e_padtouch.exe
cl %CF% e_bss.c && link %LF% /SUBSYSTEM:WINDOWS e_bss.obj kernel32.lib /OUT:e_bss.exe
