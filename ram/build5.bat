@echo off
call "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat" >nul 2>nul
cd /d "%~dp0"
cl /nologo /O1 /GS- /Gs999999 /c n_noime.c && link /nologo /NODEFAULTLIB /ENTRY:start /MANIFEST:NO /OPT:REF /SUBSYSTEM:WINDOWS n_noime.obj kernel32.lib user32.lib imm32.lib /OUT:n_noime.exe
