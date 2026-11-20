#include <windows.h>
typedef BOOL (WINAPI *GM)(LPMSG,HWND,UINT,UINT);
void __stdcall start(void){ HMODULE u=LoadLibraryW(L"user32.dll"); GM g=(GM)GetProcAddress(u,"GetMessageW"); MSG m; while(g(&m,0,0,0)>0){} ExitProcess(0); }
