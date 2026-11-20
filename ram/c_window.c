#include <windows.h>
static LRESULT CALLBACK wp(HWND h,UINT u,WPARAM w,LPARAM l){ if(u==WM_DESTROY){PostQuitMessage(0);return 0;} return DefWindowProcW(h,u,w,l);}
void __stdcall start(void){ static WNDCLASSW wc; wc.lpfnWndProc=wp; wc.hInstance=GetModuleHandleW(0); wc.lpszClassName=L"r3"; wc.hbrBackground=(HBRUSH)(COLOR_WINDOW+1);
 RegisterClassW(&wc); HWND h=CreateWindowExW(0,L"r3",L"r3",WS_OVERLAPPEDWINDOW|WS_VISIBLE,100,100,300,200,0,0,wc.hInstance,0);
#ifdef WITH_BUTTON
 CreateWindowExW(0,L"BUTTON",L"OK",WS_CHILD|WS_VISIBLE,10,10,80,30,h,0,wc.hInstance,0);
#endif
 MSG m; while(GetMessageW(&m,0,0,0)>0){TranslateMessage(&m);DispatchMessageW(&m);} ExitProcess(0); }
