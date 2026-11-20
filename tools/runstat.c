/* runstat: run a short-lived program and report its peak memory and CPU after it exits.
   Build (MSVC x64): cl /O1 runstat.c /link psapi.lib
   Usage: runstat <exe> [args...]  -> prints one JSON line to stdout (child stdout goes to NUL) */
#include <windows.h>
#include <psapi.h>
#include <stdio.h>

int wmain(int argc, wchar_t **argv) {
    if (argc < 2) { fwprintf(stderr, L"usage: runstat <exe> [args]\n"); return 2; }
    wchar_t *cmd = GetCommandLineW();
    /* skip our own argv[0] */
    if (*cmd == L'"') { cmd++; while (*cmd && *cmd != L'"') cmd++; if (*cmd) cmd++; }
    else { while (*cmd && *cmd != L' ' && *cmd != L'\t') cmd++; }
    while (*cmd == L' ' || *cmd == L'\t') cmd++;

    SECURITY_ATTRIBUTES sa = { sizeof sa, NULL, TRUE };
    HANDLE nul = CreateFileW(L"NUL", GENERIC_WRITE, FILE_SHARE_WRITE, &sa, OPEN_EXISTING, 0, NULL);
    STARTUPINFOW si = { sizeof si };
    si.dwFlags = STARTF_USESTDHANDLES;
    si.hStdOutput = nul; si.hStdError = nul; si.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
    PROCESS_INFORMATION pi;
    LARGE_INTEGER f, t0, t1; QueryPerformanceFrequency(&f);
    QueryPerformanceCounter(&t0);
    if (!CreateProcessW(NULL, cmd, NULL, NULL, TRUE, 0, NULL, NULL, &si, &pi)) {
        printf("{\"error\":%lu}\n", GetLastError()); return 1;
    }
    WaitForSingleObject(pi.hProcess, 30000);
    QueryPerformanceCounter(&t1);
    DWORD code = 0; GetExitCodeProcess(pi.hProcess, &code);
    PROCESS_MEMORY_COUNTERS_EX pm = { sizeof pm };
    GetProcessMemoryInfo(pi.hProcess, (PROCESS_MEMORY_COUNTERS *)&pm, sizeof pm);
    FILETIME c, e, k, u; GetProcessTimes(pi.hProcess, &c, &e, &k, &u);
    ULONGLONG kk = ((ULONGLONG)k.dwHighDateTime << 32 | k.dwLowDateTime);
    ULONGLONG uu = ((ULONGLONG)u.dwHighDateTime << 32 | u.dwLowDateTime);
    printf("{\"exit\":%lu,\"peak_ws_kb\":%llu,\"peak_private_kb\":%llu,\"page_faults\":%lu,"
           "\"cpu_kernel_us\":%llu,\"cpu_user_us\":%llu,\"wall_us\":%llu}\n",
           code, (ULONGLONG)pm.PeakWorkingSetSize / 1024, (ULONGLONG)pm.PeakPagefileUsage / 1024,
           pm.PageFaultCount, kk / 10, uu / 10,
           (ULONGLONG)((t1.QuadPart - t0.QuadPart) * 1000000 / f.QuadPart));
    return 0;
}
