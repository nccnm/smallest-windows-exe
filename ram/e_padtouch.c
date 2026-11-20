#include <windows.h>
#pragma section(".pad", read)
__declspec(allocate(".pad")) const unsigned char pad[1<<20] = {1,2,3};
void __stdcall start(void){ volatile unsigned s=0; for(unsigned i=0;i<sizeof pad;i+=4096) s+=pad[i]; Sleep(INFINITE); ExitProcess(s); }
