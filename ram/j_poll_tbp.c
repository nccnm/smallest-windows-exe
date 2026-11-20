#include <windows.h>
#include <timeapi.h>
void __stdcall start(void){ timeBeginPeriod(1); for(;;){ Sleep(1); } }
