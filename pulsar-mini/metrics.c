/* P3 counter collection runs off the taskbar thread. */
#include "mini.h"
#include <pdh.h>
#include <pdhmsg.h>

/* MSVC uses this symbol when a no-CRT image uses floating point. */
int _fltused;

typedef struct {
    PDH_FMT_COUNTERVALUE_ITEM_W *items;
    DWORD capacity;
} CounterBuffer;

typedef struct {
    const WCHAR *name;
    double total;
} Engine;

static HANDLE request_event, reader_thread;
static volatile LONG stop_reader;
static volatile LONG64 latest;

static DWORD counter_array(PDH_HCOUNTER counter, CounterBuffer *buffer) {
    DWORD count = 0, size = buffer->capacity;
    PDH_STATUS status;
    if (!counter) return 0;
    status = PdhGetFormattedCounterArrayW(counter, PDH_FMT_DOUBLE, &size, &count, buffer->items);
    if (status == PDH_MORE_DATA && size && size <= 4 * 1024 * 1024) {
        void *memory = HeapAlloc(GetProcessHeap(), 0, size);
        if (!memory) return 0;
        if (buffer->items) HeapFree(GetProcessHeap(), 0, buffer->items);
        buffer->items = memory;
        buffer->capacity = size;
        status = PdhGetFormattedCounterArrayW(counter, PDH_FMT_DOUBLE, &size, &count, buffer->items);
    }
    return status == ERROR_SUCCESS ? count : 0;
}

static int read_value(const PDH_FMT_COUNTERVALUE_ITEM_W *item, double *value) {
    DWORD status = item->FmtValue.CStatus;
    if (status != PDH_CSTATUS_VALID_DATA && status != PDH_CSTATUS_NEW_DATA) return 0;
    *value = item->FmtValue.doubleValue;
    return *value >= 0 && *value <= 100;
}

/* PhysicalDisk starts with the physical index. _Total is an aggregate. */
static int disk_percent(CounterBuffer *buffer, DWORD count, const WCHAR **winner) {
    double busiest = -1;
    DWORD i;
    for (i = 0; i < count; ++i) {
        const WCHAR *name = buffer->items[i].szName;
        double idle;
        if (name[0] < L'0' || name[0] > L'9' || !read_value(&buffer->items[i], &idle)) continue;
        if (100 - idle > busiest) {
            busiest = 100 - idle;
            *winner = name;
        }
    }
    return busiest < 0 ? -1 : (int)(busiest + 0.5);
}

/* GPU Engine instances are per PID. The suffix identifies adapter/physical engine. */
static const WCHAR *engine_identity(const WCHAR *name) {
    if (name[0] != L'p' || name[1] != L'i' || name[2] != L'd' || name[3] != L'_') return NULL;
    name += 4;
    while (*name >= L'0' && *name <= L'9') ++name;
    return *name == L'_' && name[1] ? name + 1 : NULL;
}

static int same_name(const WCHAR *a, const WCHAR *b) {
    while (*a == *b) {
        if (!*a) return 1;
        ++a; ++b;
    }
    return 0;
}

static int gpu_percent(CounterBuffer *buffer, DWORD count, const WCHAR **winner) {
    Engine engines[128];
    DWORD i, used = 0;
    double busiest = -1;
    for (i = 0; i < count; ++i) {
        DWORD j;
        const WCHAR *name = engine_identity(buffer->items[i].szName);
        double value;
        if (!name || !read_value(&buffer->items[i], &value)) continue;
        if (busiest < 0) {
            busiest = 0;
            *winner = name;
        }
        if (value == 0) continue;
        for (j = 0; j < used && !same_name(engines[j].name, name); ++j) {}
        if (j == used) {
            if (used == sizeof engines / sizeof engines[0]) return -1;
            engines[used].name = name;
            engines[used++].total = 0;
        }
        engines[j].total += value;
        if (engines[j].total > busiest) {
            busiest = engines[j].total;
            *winner = engines[j].name;
        }
    }
    return busiest < 0 ? -1 : busiest >= 100 ? 100 : (int)(busiest + 0.5);
}

#ifdef P1_DIAGNOSTICS
static void trace_sample(ULONGLONG tick, int disk, int gpu, const WCHAR *disk_name, const WCHAR *gpu_name) {
    CHAR line[512];
    DWORD size, written;
    HANDLE file = CreateFileA("raw\\p3-pdh.md", FILE_APPEND_DATA, FILE_SHARE_READ,
        NULL, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (file == INVALID_HANDLE_VALUE) return;
    size = (DWORD)wsprintfA(line, "| %I64u | %d | %d | %.100ls | %.100ls |\r\n", tick, disk, gpu, disk_name, gpu_name);
    WriteFile(file, line, size, &written, NULL);
    CloseHandle(file);
}
#endif

static DWORD WINAPI collect(void *host) {
    PDH_HQUERY query;
    PDH_HCOUNTER disk = NULL, gpu = NULL;
    CounterBuffer disk_buffer = {0}, gpu_buffer = {0};
    if (PdhOpenQueryW(NULL, 0, &query) != ERROR_SUCCESS) return 0;
    if (PdhAddEnglishCounterW(query, L"\\PhysicalDisk(*)\\% Idle Time", 0, &disk) != ERROR_SUCCESS) disk = NULL;
    if (PdhAddEnglishCounterW(query, L"\\GPU Engine(*)\\Utilization Percentage", 0, &gpu) != ERROR_SUCCESS) gpu = NULL;
    while (WaitForSingleObject(request_event, INFINITE) == WAIT_OBJECT_0 && !stop_reader) {
        const WCHAR *disk_name = L"--", *gpu_name = L"--";
        int disk_value = -1, gpu_value = -1;
        ULONGLONG tick, old, packed;
        if (PdhCollectQueryData(query) == ERROR_SUCCESS) {
            disk_value = disk_percent(&disk_buffer, counter_array(disk, &disk_buffer), &disk_name);
            gpu_value = gpu_percent(&gpu_buffer, counter_array(gpu, &gpu_buffer), &gpu_name);
        }
        tick = GetTickCount64();
        packed = (tick << 16) | (unsigned)(disk_value + 1) | (unsigned)((gpu_value + 1) << 8);
        old = (ULONGLONG)InterlockedExchange64(&latest, (LONG64)packed);
        if (((old ^ packed) & 0xffff) || tick - (old >> 16) > 3000)
            PostMessageW((HWND)host, METRICS_READY, 0, 0);
#ifdef P1_DIAGNOSTICS
        trace_sample(tick, disk_value, gpu_value, disk_name, gpu_name);
#endif
    }
    PdhCloseQuery(query);
    if (disk_buffer.items) HeapFree(GetProcessHeap(), 0, disk_buffer.items);
    if (gpu_buffer.items) HeapFree(GetProcessHeap(), 0, gpu_buffer.items);
    return 0;
}

void metrics_start(HWND host) {
    request_event = CreateEventW(NULL, FALSE, FALSE, NULL);
    if (!request_event) return;
    reader_thread = CreateThread(NULL, 0, collect, host, 0, NULL);
    if (!reader_thread) {
        CloseHandle(request_event);
        request_event = NULL;
    }
}

void metrics_read(int *disk, int *gpu) {
    ULONGLONG packed = (ULONGLONG)InterlockedCompareExchange64(&latest, 0, 0);
    if (GetTickCount64() - (packed >> 16) > 3000) packed = 0;
    *disk = (int)(packed & 255) - 1;
    *gpu = (int)((packed >> 8) & 255) - 1;
}

void metrics_request(void) {
    if (request_event) SetEvent(request_event);
}

void metrics_stop(void) {
    if (!reader_thread) return;
    InterlockedExchange(&stop_reader, 1);
    SetEvent(request_event);
    /* A wedged provider must not hold the image in DLL detach. */
    if (WaitForSingleObject(reader_thread, 500) != WAIT_OBJECT_0)
        TerminateProcess(GetCurrentProcess(), 0);
    CloseHandle(reader_thread);
    CloseHandle(request_event);
}
