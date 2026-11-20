#include <windows.h>
void __stdcall start(void){ SetTimer(0,0,1000,0); MSG m; while(GetMessageW(&m,0,0,0)>0){DispatchMessageW(&m);} ExitProcess(0); }
