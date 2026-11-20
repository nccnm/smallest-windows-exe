#include <windows.h>
static LRESULT CALLBACK wp(HWND h,UINT u,WPARAM w,LPARAM l){ if(u==WM_DESTROY){PostQuitMessage(0);return 0;} return DefWindowProcW(h,u,w,l);}
void __stdcall start(void){ static WNDCLASSW wc; wc.lpfnWndProc=wp; wc.hInstance=GetModuleHandleW(0); wc.lpszClassName=L"r3"; wc.hbrBackground=(HBRUSH)(COLOR_WINDOW+1);
 RegisterClassW(&wc); CreateWindowExW(0,L"r3",L"r3 trim",WS_OVERLAPPEDWINDOW|WS_VISIBLE,100,100,300,200,0,0,wc.hInstance,0);
 int trimmed=0; DWORD t0=GetTickCount();
 for(;;){ DWORD el=GetTickCount()-t0; DWORD to = trimmed?INFINITE:(el>=3000?0:3000-el);
  DWORD r=MsgWaitForMultipleObjects(0,0,FALSE,to,QS_ALLINPUT);
  if(r==WAIT_TIMEOUT && !trimmed){ SetProcessWorkingSetSize(GetCurrentProcess(),(SIZE_T)-1,(SIZE_T)-1); trimmed=1; }
  MSG m; while(PeekMessageW(&m,0,0,0,PM_REMOVE)){ if(m.message==WM_QUIT) ExitProcess(0); TranslateMessage(&m); DispatchMessageW(&m);} } }
