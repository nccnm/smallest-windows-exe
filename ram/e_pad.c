#include <windows.h>
#pragma section(".pad", read)
/* 1 MB initialized data, never touched at runtime */
__declspec(allocate(".pad")) const unsigned char pad[1<<20] = {1,2,3};
void __stdcall start(void){ volatile const void* p = pad; (void)p; Sleep(INFINITE); ExitProcess(0); }
