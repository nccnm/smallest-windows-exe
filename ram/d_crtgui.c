#include <windows.h>
#include <stdio.h>
int WINAPI wWinMain(HINSTANCE a,HINSTANCE b,PWSTR c,int d){ char buf[16]; sprintf(buf,"%d",d); MSG m; while(GetMessageW(&m,0,0,0)>0){DispatchMessageW(&m);} return 0; }
