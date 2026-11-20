#include <windows.h>
static unsigned char big[16<<20]; /* 16 MB .bss, untouched */
void __stdcall start(void){ volatile void* p=big; (void)p; Sleep(INFINITE); ExitProcess(0); }
