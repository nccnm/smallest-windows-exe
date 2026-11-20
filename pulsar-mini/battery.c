/* Minimal read-only HID++ 2.0 battery queries for receiver 046D:C547.
   Independent C implementation based on the public protocol and local driver analysis. */
#include "mini.h"
#include <cfgmgr32.h>
#include <hidsdi.h>
#include <hidpi.h>

typedef struct { HANDLE handle, event; BYTE software_id; } Link;
static int transfer(Link *l, BYTE *bytes, int write, DWORD timeout) {
    OVERLAPPED ov = {0};
    DWORD count = 0;
    BOOL done;
    ov.hEvent = l->event;
    ResetEvent(l->event);
    done = write ? WriteFile(l->handle, bytes, 20, &count, &ov) : ReadFile(l->handle, bytes, 20, &count, &ov);
    if (!done) {
        if (GetLastError() != ERROR_IO_PENDING) return 0;
        if (WaitForSingleObject(l->event, timeout) != WAIT_OBJECT_0) {
            CancelIoEx(l->handle, &ov);
            /* Drain completion before the OVERLAPPED and caller's buffer go out of scope. */
            GetOverlappedResult(l->handle, &ov, &count, TRUE);
            return 0;
        }
        if (!GetOverlappedResult(l->handle, &ov, &count, FALSE)) return 0;
    }
    return (int)count;
}
static int request(Link *l, BYTE device, BYTE feature, BYTE fn, BYTE p0, BYTE p1, BYTE p2, BYTE *reply) {
    BYTE message[20] = {0};
    BYTE command = (BYTE)((fn << 4) | l->software_id);
    /* G502 X on slot 1 can answer the first ping late while its radio wakes. */
    ULONGLONG deadline, timeout = device == 1 && feature == 0 && fn == 1 ? 1500 : 500;
    message[0] = 0x11; message[1] = device; message[2] = feature; message[3] = command;
    message[4] = p0; message[5] = p1; message[6] = p2;
    if (transfer(l, message, 1, 150) != 20) return 0;
    deadline = GetTickCount64() + timeout;
    while (GetTickCount64() < deadline) {
        ULONGLONG left = deadline - GetTickCount64();
        if (left > timeout) break;
        if (transfer(l, reply, 0, (DWORD)left) < 7) continue;
        if (reply[0] != 0x11 || reply[1] != device) continue;
        if (reply[2] == feature && reply[3] == command) return 1;
        if ((reply[2] == 0xFF || reply[2] == 0x8F) && reply[3] == feature && reply[4] == command) return 0;
    }
    return 0;
}
static BYTE feature_index(Link *l, BYTE device, USHORT feature) {
    BYTE reply[20];
    if (request(l, device, 0, 0, (BYTE)(feature >> 8), (BYTE)feature, 0, reply)) return reply[4];
    return 0;
}
static int probe(Link *l, BYTE device, Battery *b) {
    BYTE reply[20], feature;
    int unified = 1;
    if (!request(l, device, 0, 1, 0, 0, 0x5A, reply) || reply[4] < 2 || reply[6] != 0x5A) return 0;
    feature = feature_index(l, device, 0x1004);
    if (!feature || !request(l, device, feature, 1, 0, 0, 0, reply)) {
        feature = feature_index(l, device, 0x1000); unified = 0;
        if (!feature || !request(l, device, feature, 0, 0, 0, 0, reply)) return 0;
    }
    b->percent = reply[4];
    if (b->percent > 100) return 0;
    if (unified && !b->percent && reply[5]) {
        b->percent = (reply[5] & 8) ? 100 : (reply[5] & 4) ? 60 : (reply[5] & 2) ? 20 : 5;
        b->approximate = 1;
    }
    b->charging = reply[6] >= 1 && reply[6] <= (unified ? 3 : 4);
    if (!unified && !b->percent && reply[6] == 3) b->percent = 100;
    b->device = device; b->feature = feature;
    lstrcpyW(b->name, L"Logitech wireless device");
    feature = feature_index(l, device, 0x0005);
    if (feature && request(l, device, feature, 0, 0, 0, 0, reply)) {
        char name[128];
        int total = reply[4], pos = 0;
        if (total > 127) total = 127;
        while (pos < total) {
            int i;
            if (!request(l, device, feature, 1, (BYTE)pos, 0, 0, reply)) break;
            for (i = 4; i < 20 && pos < total; ++i) name[pos++] = (char)reply[i];
        }
        if (pos == total && pos) {
            name[pos] = 0;
            MultiByteToWideChar(CP_UTF8, 0, name, -1, b->name, 128);
            b->name[127] = 0;
        }
    }
    b->found = 1;
    return 1;
}
void read_battery(Battery *result, BYTE software_id) {
    GUID guid;
    WCHAR *paths = NULL, *path;
    ULONG chars;
    int attempt;
    CONFIGRET status = CR_FAILURE;
    result->found = 0; result->approximate = 0;
    HidD_GetHidGuid(&guid);
    for (attempt = 0; attempt < 3; ++attempt) {
        if (CM_Get_Device_Interface_List_SizeW(&chars, &guid, NULL, CM_GET_DEVICE_INTERFACE_LIST_PRESENT) != CR_SUCCESS ||
            chars < 2 || chars > 1048576) return;
        paths = HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, (SIZE_T)chars * sizeof(WCHAR));
        if (!paths) return;
        status = CM_Get_Device_Interface_ListW(&guid, NULL, paths, chars, CM_GET_DEVICE_INTERFACE_LIST_PRESENT);
        if (status == CR_SUCCESS) break;
        HeapFree(GetProcessHeap(), 0, paths); paths = NULL;
        if (status != CR_BUFFER_SMALL) return;
    }
    if (!paths) return;
    for (path = paths; *path; path += lstrlenW(path) + 1) {
        HANDLE h;
        HIDD_ATTRIBUTES attr = { sizeof attr };
        PHIDP_PREPARSED_DATA preparsed;
        HIDP_CAPS caps;
        int match = 0;
        Link link;
        link.software_id = software_id;
        h = CreateFileW(path, 0, FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_EXISTING, 0, NULL);
        if (h != INVALID_HANDLE_VALUE) {
            if (HidD_GetAttributes(h, &attr) && attr.VendorID == 0x046D && attr.ProductID == 0xC547 &&
                HidD_GetPreparsedData(h, &preparsed)) {
                if (HidP_GetCaps(preparsed, &caps) == HIDP_STATUS_SUCCESS)
                    match = caps.UsagePage == 0xFF00 && caps.Usage == 2 && caps.OutputReportByteLength == 20 && caps.InputReportByteLength == 20;
                HidD_FreePreparsedData(preparsed);
            }
            CloseHandle(h);
        }
        link.handle = match ? CreateFileW(path, GENERIC_READ | GENERIC_WRITE,
            FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_EXISTING, FILE_FLAG_OVERLAPPED, NULL) : INVALID_HANDLE_VALUE;
        if (link.handle == INVALID_HANDLE_VALUE) continue;
        link.event = CreateEventW(NULL, TRUE, FALSE, NULL);
        if (link.event) {
            BYTE device;
            for (device = 1; device <= 6; ++device) if (probe(&link, device, result)) break;
            CloseHandle(link.event);
        }
        CloseHandle(link.handle);
        if (result->found) break;
    }
    HeapFree(GetProcessHeap(), 0, paths);
}
