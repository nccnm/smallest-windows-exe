@echo off
call "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat" >nul
cd /d "%~dp0"
set CF=/nologo /O1 /GS- /Gs999999 /c
set LF=/nologo /NODEFAULTLIB /ENTRY:start /MANIFEST:NO /OPT:REF /OPT:ICF
cl %CF% a_sleep.c && link %LF% /SUBSYSTEM:CONSOLE a_sleep.obj kernel32.lib /OUT:a_sleep_con.exe
link %LF% /SUBSYSTEM:WINDOWS a_sleep.obj kernel32.lib /OUT:a_sleep_gui.exe
cl %CF% b_getmsg.c && link %LF% /SUBSYSTEM:WINDOWS b_getmsg.obj kernel32.lib user32.lib /OUT:b_getmsg.exe
cl %CF% c_window.c && link %LF% /SUBSYSTEM:WINDOWS c_window.obj kernel32.lib user32.lib /OUT:c_window.exe
cl %CF% /DWITH_BUTTON c_window.c /Foc_button.obj && link %LF% /SUBSYSTEM:WINDOWS c_button.obj kernel32.lib user32.lib /OUT:f_button_v5.exe
link /nologo /NODEFAULTLIB /ENTRY:start /OPT:REF /SUBSYSTEM:WINDOWS c_button.obj kernel32.lib user32.lib /MANIFEST:EMBED /MANIFESTINPUT:comctl6.manifest /OUT:f_button_v6.exe
cl /nologo /O1 /MD d_crt.c /Fed_crt_md.exe >nul
cl /nologo /O1 /MT d_crt.c /Fed_crt_mt.exe >nul
cl /nologo /O1 /MD d_crtgui.c /Fed_crtgui_md.exe /link /SUBSYSTEM:WINDOWS user32.lib >nul
cl %CF% e_pad.c && link %LF% /SUBSYSTEM:WINDOWS e_pad.obj kernel32.lib /OUT:e_pad.exe
cl %CF% g_poll.c && link %LF% /SUBSYSTEM:WINDOWS g_poll.obj kernel32.lib /OUT:g_poll.exe
cl %CF% h_timer.c && link %LF% /SUBSYSTEM:WINDOWS h_timer.obj kernel32.lib user32.lib /OUT:h_timer.exe
cl %CF% i_eco.c && link %LF% /SUBSYSTEM:WINDOWS i_eco.obj kernel32.lib /OUT:i_eco.exe
