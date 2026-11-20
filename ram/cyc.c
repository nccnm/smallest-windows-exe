/* cyc.exe <exe> <settle_s> <window_s> : launch exe, wait, then report cycle-time delta and context switches via thread cycle */
#include <windows.h>
#include <stdio.h>
int main(int c,char**v){ STARTUPINFOA si={sizeof si}; PROCESS_INFORMATION pi;
 if(!CreateProcessA(v[1],0,0,0,FALSE,0,0,0,&si,&pi)) return 1;
 Sleep(atoi(v[2])*1000); ULONG64 c0,c1; FILETIME a,b,k0,u0,k1,u1; QueryProcessCycleTime(pi.hProcess,&c0); GetProcessTimes(pi.hProcess,&a,&b,&k0,&u0);
 LARGE_INTEGER f,t0,t1; QueryPerformanceFrequency(&f); QueryPerformanceCounter(&t0);
 Sleep(atoi(v[3])*1000); QueryProcessCycleTime(pi.hProcess,&c1); GetProcessTimes(pi.hProcess,&a,&b,&k1,&u1); QueryPerformanceCounter(&t1);
 double secs=(double)(t1.QuadPart-t0.QuadPart)/f.QuadPart;
 ULONG64 kt=(((ULONG64)k1.dwHighDateTime<<32|k1.dwLowDateTime)-((ULONG64)k0.dwHighDateTime<<32|k0.dwLowDateTime));
 ULONG64 ut=(((ULONG64)u1.dwHighDateTime<<32|u1.dwLowDateTime)-((ULONG64)u0.dwHighDateTime<<32|u0.dwLowDateTime));
 printf("{\"exe\":\"%s\",\"window_s\":%.1f,\"cycles\":%llu,\"Mcycles_per_s\":%.3f,\"times_ms\":%.1f}\n", v[1], secs, c1-c0, (c1-c0)/secs/1e6, (kt+ut)/1e4);
 TerminateProcess(pi.hProcess,0); return 0; }
