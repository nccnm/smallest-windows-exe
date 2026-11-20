#include <windows.h>
void __stdcall start(void) {
    static const char msg[] = "Hello, World!\r\n";
    DWORD n;
    WriteFile(GetStdHandle(STD_OUTPUT_HANDLE), msg, sizeof msg - 1, &n, NULL);
    Sleep(INFINITE); /* stay alive so Task Manager can see it */
}

