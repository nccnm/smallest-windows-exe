/* GUI hello without the C runtime: user32 MessageBoxA + kernel32 ExitProcess. */
#include <windows.h>
void __stdcall start(void) {
    MessageBoxA(NULL, "Hello, World!", "Hello", MB_OK);
    ExitProcess(0);
}
