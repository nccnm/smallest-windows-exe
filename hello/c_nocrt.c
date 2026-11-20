/* Console hello without the C runtime: only kernel32 imports. */
#include <windows.h>
void __stdcall start(void) {
    static const char msg[] = "Hello, World!\r\n";
    DWORD n;
    WriteFile(GetStdHandle(STD_OUTPUT_HANDLE), msg, sizeof msg - 1, &n, NULL);
    ExitProcess(0);
}
