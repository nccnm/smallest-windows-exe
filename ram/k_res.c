#include <windows.h>
#include <stdio.h>
typedef LONG (NTAPI *Q)(PULONG,PULONG,PULONG);
int main(void){ ULONG mn,mx,cur; Q q=(Q)GetProcAddress(GetModuleHandleA("ntdll.dll"),"NtQueryTimerResolution"); q(&mn,&mx,&cur);
 printf("min(coarsest)=%.4f ms max(finest)=%.4f ms current=%.4f ms\n",mn/1e4,mx/1e4,cur/1e4); return 0; }
