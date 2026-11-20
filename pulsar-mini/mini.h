#pragma once
#define WIN32_LEAN_AND_MEAN
#define _WIN32_WINNT 0x0A00
#include <windows.h>
typedef struct {
    int percent, charging, found, approximate;
    BYTE device, feature;
    WCHAR name[128];
} Battery;
void read_battery(Battery *result, BYTE software_id);
DWORD battery_list(void);
#ifdef DISK_GPU
#define METRICS_READY (WM_APP + 1)
void metrics_start(HWND host);
void metrics_request(void);
void metrics_read(int *disk, int *gpu);
void metrics_stop(void);
#endif
