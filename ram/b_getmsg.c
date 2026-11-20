#include <windows.h>
void __stdcall start(void){ MSG m; while(GetMessageW(&m,0,0,0)>0){DispatchMessageW(&m);} ExitProcess(0); }
