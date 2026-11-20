@echo off
call "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat" >nul 2>nul
cd /d "%~dp0"
set CF=/nologo /O1 /GS- /Gs999999 /c
set LF=/nologo /NODEFAULTLIB /ENTRY:start /MANIFEST:NO /OPT:REF /SUBSYSTEM:WINDOWS
cl %CF% l_trim.c && link %LF% l_trim.obj kernel32.lib user32.lib /OUT:l_trim.exe
cl %CF% m_dyn.c && link %LF% m_dyn.obj kernel32.lib /OUT:m_dyn.exe
