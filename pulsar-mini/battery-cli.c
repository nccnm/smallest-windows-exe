#include "mini.h"
static void write_text(const char *text, DWORD bytes) {
    HANDLE out = GetStdHandle(STD_OUTPUT_HANDLE);
    DWORD written;
    while (bytes) {
        if (!WriteFile(out, text, bytes, &written, NULL) || !written) break;
        text += written; bytes -= written;
    }
}
DWORD battery_list(void) {
    Battery battery = {0};
    char name[512], percent[8];
    DWORD n = 0;
    HANDLE output = GetStdHandle(STD_OUTPUT_HANDLE);
    if (!output || output == INVALID_HANDLE_VALUE) AttachConsole(ATTACH_PARENT_PROCESS);
    read_battery(&battery, 0x0A);
    if (!battery.found) {
        static const char unavailable[] = "046D:C547: battery unavailable (receiver absent, device asleep, or unsupported feature)\r\n";
        write_text(unavailable, sizeof unavailable - 1);
        return 1;
    }
    {
        int bytes = WideCharToMultiByte(CP_UTF8,0,battery.name,-1,name,sizeof name,NULL,NULL);
        if (bytes > 1) write_text(name,(DWORD)bytes-1);
    }
    if (battery.approximate) write_text(", ~",3); else write_text(", ",2);
    if (battery.percent == 100) percent[n++] = '1';
    if (battery.percent >= 10) percent[n++] = (char)('0' + (battery.percent/10)%10);
    percent[n++] = (char)('0' + battery.percent%10);
    percent[n++] = '%';
    write_text(percent,n);
    if (battery.charging) write_text(" charging",9);
    write_text("\r\n",2);
    return 0;
}
#ifndef BATTERY_LIST_LIBRARY
void __stdcall start(void) { ExitProcess(battery_list()); }
#endif
