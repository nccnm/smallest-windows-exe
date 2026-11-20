/* launch.exe <flag> <exe> : starts exe with given creation flag, prints pid, exits leaving child running */
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
int main(int c,char**v){ DWORD f=0; if(!strcmp(v[1],"new"))f=CREATE_NEW_CONSOLE; else if(!strcmp(v[1],"nowin"))f=CREATE_NO_WINDOW; else if(!strcmp(v[1],"detached"))f=DETACHED_PROCESS;
 STARTUPINFOA si={sizeof si}; PROCESS_INFORMATION pi; if(!CreateProcessA(v[2],0,0,0,FALSE,f,0,0,&si,&pi)){printf("fail %lu\n",GetLastError());return 1;}
 printf("%lu\n",pi.dwProcessId); return 0; }
