/* Personal x64 Win32 experiment. No CRT, no injected code, no Explorer patches. */
#include "mini.h"
#ifndef BATTERY_ONLY
#include <winsock2.h>
#include <ws2tcpip.h>
#include <iphlpapi.h>
#include <netioapi.h>
#include <winternl.h>
#endif
#include <imm.h>

#ifdef BATTERY_ONLY
#define APP "Wireless Battery mini"
#define CLASS "BatteryMini"
#else
#define APP "Pulsar mini"
#define CLASS "PulsarMini"
#endif
static HWND host, bar, taskbar;
static HINSTANCE instance;
static HFONT font;
static UINT taskbar_created, dpi;
#ifdef BATTERY_ONLY
static CHAR line1[128], line2[64];
#else
static CHAR line1[64], line2[64];
#endif
static int width, height, light;
#ifdef FULL_UI
static int offset_dip, preview;
#else
#define offset_dip 0
#define preview 0
#endif
static ULONGLONG timer_ticks, paint_count;
#ifdef P1_DIAGNOSTICS
static ULONGLONG previous_tick;
static void trace(const CHAR *event) {
    CHAR row[1024];
    RECT r = {0};
    DWORD owner = 0, written;
    HANDLE file;
    if (taskbar) GetWindowThreadProcessId(taskbar, &owner);
    if (bar) GetWindowRect(bar, &r);
#ifdef BATTERY_ONLY
    const CHAR *path = "raw\\p1-battery.md";
#else
    const CHAR *path = "raw\\p1-pulsar.md";
#endif
    file = CreateFileA(path, FILE_APPEND_DATA, FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (file == INVALID_HANDLE_VALUE) return;
    wsprintfA(row, "| %I64u | %s | %lu | %lu | %p | %p | %u | %d | %ld,%ld,%ld,%ld | %d | %d | %I64u | %I64u |\r\n",
        GetTickCount64(), event, GetCurrentProcessId(), owner, bar, taskbar, dpi, light,
        r.left,r.top,r.right,r.bottom, IsWindowVisible(bar), IsWindowVisible(taskbar), timer_ticks,paint_count);
    WriteFile(file,row,(DWORD)lstrlenA(row),&written,NULL); CloseHandle(file);
}
#else
#define trace(event) ((void)0)
#endif
#ifdef BATTERY_ONLY
static Battery incoming, battery;
static HANDLE worker;
static ULONGLONG next_poll, last_good;
static int last_poll_ok;
static DWORD WINAPI poll_battery(void *unused) {
    (void)unused;
    read_battery(&incoming, 0x0B);
    PostMessageW(host, WM_APP, 0, 0);
    return 0;
}
#else
static ULONGLONG idle0, cpu_time0, net_tick, net_next, net_down, net_up;
typedef struct { NET_LUID luid; DWORD index, in0, out0; int valid; } Net;
static Net nets[8];
static ULONG net_count;
static ULONGLONG refresh_network;
#ifdef NET_TABLE
static MIB_IFTABLE *legacy_table;
static int network_table(void) {
    DWORD bytes = 65536;
    if (!legacy_table) legacy_table = GlobalAlloc(GMEM_FIXED, bytes);
    return legacy_table && GetIfTable(legacy_table, &bytes, FALSE) == NO_ERROR;
}
#endif
static int network_valid;
static DWORD cpu_count;
#endif

static void theme(void) {
    DWORD value = 0, bytes = sizeof value;
    RegGetValueA(HKEY_CURRENT_USER, "Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
                 "SystemUsesLightTheme", RRF_RT_REG_DWORD, NULL, &value, &bytes);
    light = value != 0;
}
static void layout(void) {
    RECT r, tray;
    UINT new_dpi;
    HWND notify;
    if (!IsWindow(bar)) return;
    new_dpi = GetDpiForWindow(preview ? bar : taskbar);
    if (!new_dpi) new_dpi = 96;
    if (dpi != new_dpi || !font) {
        HFONT replacement = CreateFontA(-MulDiv(12, new_dpi, 96), 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, NONANTIALIASED_QUALITY,
            DEFAULT_PITCH, "Segoe UI");
        if (replacement) {
            if (font) DeleteObject(font);
            font = replacement;
        }
        dpi = new_dpi;
    }
#ifdef BATTERY_ONLY
    width = MulDiv(220, dpi, 96);
#elif defined(DISK_GPU)
    width = MulDiv(312, dpi, 96);
#else
    width = MulDiv(235, dpi, 96);
#endif
    if (preview) { height = MulDiv(48, dpi, 96); return; }
    if (!GetClientRect(taskbar, &r)) return;
    height = r.bottom;
    notify = FindWindowExA(taskbar, NULL, "TrayNotifyWnd", NULL);
    tray.left = r.right;
    if (notify && GetWindowRect(notify, &tray)) MapWindowPoints(NULL, taskbar, (POINT *)&tray, 2);
#if defined(FULL_UI) || defined(BATTERY_ONLY)
    {
        const CHAR *classes[] = {
#ifdef FULL_UI
            "PulsarOverlay", "WirelessBatteryWidget",
#endif
#ifdef BATTERY_ONLY
            "PulsarMini",
#endif
        };
        unsigned i;
        for (i = 0; i < sizeof classes/sizeof classes[0]; ++i) {
            HWND other = FindWindowExA(taskbar, NULL, classes[i], NULL);
            RECT occupied;
            if (other && other != bar && IsWindowVisible(other) && GetWindowRect(other, &occupied)) {
                MapWindowPoints(NULL, taskbar, (POINT *)&occupied, 2);
                if (occupied.left < tray.left) tray.left = occupied.left;
            }
        }
    }
#endif
    /* A manual offset avoids another monitor's reserved area, without UI Automation. */
    {
        int x = tray.left - width - MulDiv(8 + offset_dip, dpi, 96);
        RECT old;
        if (x < 0) x = 0;
        GetWindowRect(bar, &old);
        MapWindowPoints(NULL, taskbar, (POINT *)&old, 2);
        if (old.left != x || old.top != 0 || old.right - old.left != width || old.bottom != height) {
            SetWindowPos(bar, HWND_TOP, x, 0, width, height, SWP_NOACTIVATE);
            trace("layout");
        }
    }
}
static LRESULT CALLBACK wndproc(HWND, UINT, WPARAM, LPARAM);
static void attach(void) {
#ifdef BATTERY_ONLY
    if (IsWindow(bar) && (preview || IsWindow(taskbar))) return;
    HWND parent = preview ? NULL : FindWindowA("Shell_TrayWnd", NULL);
    if (!preview && !parent) return;
    if (IsWindow(bar) && (preview || taskbar == parent)) return;
    if (IsWindow(bar)) DestroyWindow(bar);
#else
    BOOL alive = IsWindow(bar);
    if (alive && (preview || IsWindow(taskbar))) return;
    HWND parent = preview ? NULL : FindWindowA("Shell_TrayWnd", NULL);
    if (!preview && !parent) return;
    if (alive) DestroyWindow(bar);
#endif
    taskbar = parent;
    bar = CreateWindowExA(preview ? 0 : WS_EX_LAYERED | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE, CLASS, APP,
        preview ? WS_OVERLAPPEDWINDOW : WS_CHILD,
        preview ? 100 : 0, preview ? 100 : 0, 500, 120, parent, NULL, instance, NULL);
    if (!bar) return;
    if (!preview) SetLayeredWindowAttributes(bar, RGB(255,0,255), 255, LWA_COLORKEY);
    layout();
    if (preview) SetWindowPos(bar, NULL, 100, 100, width + 32, height + 48, SWP_NOZORDER | SWP_NOACTIVATE);
    SetWindowPos(bar, HWND_TOP, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_SHOWWINDOW);
    trace("attached");
}

#ifndef BATTERY_ONLY
/* Timer updates use the window DC. Windows-initiated repaints validate their region. */
static void draw(HWND w, int repaint) {
    PAINTSTRUCT ps;
    HDC dc = repaint ? BeginPaint(w, &ps) : GetDC(w);
    if (!dc) return;
    RECT r = { 0, 0, width, height };
    HGDIOBJ previous = font ? SelectObject(dc, font) : NULL;
    RECT upper;
    int first_y, second_y, x;
#ifdef FULL_UI
    if (preview) GetClientRect(w, &r);
#endif
    x = MulDiv(4, dpi, 96);
    first_y = (r.bottom - MulDiv(30, dpi, 96)) / 2;
    second_y = first_y + MulDiv(15, dpi, 96);
    upper = r;
    upper.bottom = second_y;
    r.top = second_y;
    SetBkColor(dc, preview ? (light ? RGB(245,245,245) : RGB(32,32,32)) : RGB(255,0,255));
    SetTextColor(dc, light ? RGB(1,1,1) : RGB(255,255,255));
    ExtTextOutA(dc, x, first_y, ETO_OPAQUE, &upper, line1, lstrlenA(line1), NULL);
    ExtTextOutA(dc, x, second_y, ETO_OPAQUE, &r, line2, lstrlenA(line2), NULL);
    if (previous) SelectObject(dc, previous);
    if (repaint) EndPaint(w, &ps);
    else ReleaseDC(w, dc);
    ++paint_count;
}
#endif

#ifdef DISK_GPU
static CHAR base_cpu[64], base_net[64];
static void present_metrics(void) {
    int disk, gpu;
    CHAR combined[64], disk_text[8] = "--", gpu_text[8] = "--";
    metrics_read(&disk, &gpu);
    if (disk >= 0) wsprintfA(disk_text, "%d%%", disk);
    if (gpu >= 0) wsprintfA(gpu_text, "%d%%", gpu);
    wsprintfA(combined, "%s   Disk %s   GPU %s", base_cpu, disk_text, gpu_text);
    if (lstrcmpA(line1, combined) || lstrcmpA(line2, base_net)) {
        lstrcpyA(line1, combined); lstrcpyA(line2, base_net);
        if (bar) {
#ifdef FULL_UI
            if (preview) SetWindowTextA(bar, combined);
#endif
            draw(bar, FALSE);
        }
    }
}
#endif

static void sample(void) {
    CHAR a[128], b[128];
#ifdef STATIC_SAMPLE
    lstrcpyA(a, "Pulsar mini");
    lstrcpyA(b, "Taskbar resident");
#elif defined(BATTERY_ONLY)
    ULONGLONG now = GetTickCount64();
    if (!worker && now >= next_poll) {
        worker = CreateThread(NULL, 0, poll_battery, NULL, 0, NULL);
        next_poll = now + (worker ? 60000 : 5000);
    }
    if (battery.found && now - last_good <= 1800000) {
        if (!WideCharToMultiByte(CP_ACP, 0, battery.name, -1, a, sizeof a, NULL, NULL))
            lstrcpyA(a, "Logitech wireless device");
        wsprintfA(b, "Battery %s%d%%%s%s", battery.approximate ? "~" : "", battery.percent,
            battery.charging ? " charging" : "", last_poll_ok ? "" : " (stale)");
    } else {
        lstrcpyA(a, "Logitech G502 X receiver");
        lstrcpyA(b, worker ? "Reading battery..." : "Battery unavailable");
    }
#else
    ULONGLONG performance[64], cpu_time;
    MEMORYSTATUSEX memory = { sizeof memory };
    MIB_IF_TABLE2 *table = NULL;
#ifndef NET_TABLE
    MIB_IFROW storage;
#endif
    MIB_IFROW *row;
    Net next[8];
    ULONGLONG now = GetTickCount64(), elapsed = now - net_tick, down = 0, up = 0;
    int percent = -1;
    ULONG i, j, count = 0;
    if (!cpu_count) cpu_count = GetActiveProcessorCount(ALL_PROCESSOR_GROUPS);
    if (cpu_count && NtQuerySystemInformation(SystemPerformanceInformation,
            performance, sizeof performance, NULL) >= 0 && QueryUnbiasedInterruptTime(&cpu_time)) {
        /* SystemPerformanceInformation starts with aggregate idle time in 100 ns units. */
        ULONGLONG idle = performance[0];
        if (cpu_time0 && cpu_time > cpu_time0 && idle >= idle0) {
            ULONGLONG total = (cpu_time - cpu_time0) * cpu_count;
            ULONGLONG idle_delta = idle - idle0;
            percent = idle_delta >= total ? 0 : (int)((total - idle_delta) * 100 / total);
        }
        cpu_time0 = cpu_time;
        idle0 = idle;
    }
    if (now >= net_next) {
    if (now >= refresh_network && GetIfTable2Ex(MibIfTableNormalWithoutStatistics, &table) == NO_ERROR) {
        for (i = 0; i < table->NumEntries && count < 8; ++i) {
            MIB_IF_ROW2 *r = &table->Table[i];
            if (r->OperStatus != IfOperStatusUp || !r->InterfaceAndOperStatusFlags.HardwareInterface ||
                r->Type == IF_TYPE_SOFTWARE_LOOPBACK || r->Type == IF_TYPE_TUNNEL) continue;
            for (j = 0; j < net_count; ++j) if (nets[j].luid.Value == r->InterfaceLuid.Value) break;
            if (j < net_count) next[count] = nets[j];
            else { next[count].luid = r->InterfaceLuid; next[count].valid = 0; }
            next[count].index = r->InterfaceIndex;
            ++count;
        }
        for (i = 0; i < count; ++i) nets[i] = next[i];
        net_count = count;
        FreeMibTable(table);
        refresh_network = now + 30000;
    }
    network_valid = net_count != 0;
#ifdef NET_TABLE
    network_valid = network_valid && network_table();
#endif
    for (i = 0; i < net_count; ++i) {
#ifdef NET_TABLE
        if (!network_valid) { nets[i].valid = 0; continue; }
        for (j = 0; j < legacy_table->dwNumEntries; ++j) if (legacy_table->table[j].dwIndex == nets[i].index) break;
        if (j == legacy_table->dwNumEntries) { nets[i].valid = 0; network_valid = 0; continue; }
        row = &legacy_table->table[j];
#else
        row = &storage; row->dwIndex = nets[i].index;
        if (GetIfEntry(row) != NO_ERROR) { nets[i].valid = 0; network_valid = 0; continue; }
#endif
        if (row->dwOperStatus != IF_OPER_STATUS_OPERATIONAL) {
            nets[i].valid = 0; network_valid = 0; continue;
        }
        /* One wrap is safe on this machine's 1-Gbit/s link, even at the idle cadence.
           After long scheduling pauses, take a fresh baseline instead of guessing. */
        if (nets[i].valid && elapsed < 10000) {
            down += (DWORD)(row->dwInOctets - nets[i].in0);
            up += (DWORD)(row->dwOutOctets - nets[i].out0);
        }
        nets[i].in0 = row->dwInOctets; nets[i].out0 = row->dwOutOctets; nets[i].valid = 1;
    }
    net_down = elapsed ? down * 1000 / elapsed / 1024 : 0;
    net_up = elapsed ? up * 1000 / elapsed / 1024 : 0;
    net_next = now + (down + up <= elapsed * 16 ? 5000 : 1000);
    net_tick = now;
    }
    GlobalMemoryStatusEx(&memory);
    if (percent >= 0) wsprintfA(a, "CPU %d%%    RAM %lu%%", percent, memory.dwMemoryLoad);
    else wsprintfA(a, "CPU --    RAM %lu%%", memory.dwMemoryLoad);
    if (network_valid) {
        wsprintfA(b, "Down %I64u   Up %I64u KiB/s", net_down, net_up);
    } else lstrcpyA(b, "Network unavailable");
#endif
#ifdef DISK_GPU
    lstrcpyA(base_cpu, a); lstrcpyA(base_net, b);
    present_metrics();
    metrics_request();
#else
    if (lstrcmpA(line1, a) || lstrcmpA(line2, b)) {
#ifdef BATTERY_ONLY
        lstrcpyA(line1, a); lstrcpyA(line2, b);
        if (IsWindow(bar)) {
#ifdef FULL_UI
            if (preview) SetWindowTextA(bar, a);
#endif
            InvalidateRect(bar, NULL, FALSE);
        }
#else
        lstrcpyA(line1, a); lstrcpyA(line2, b);
        if (bar) {
#ifdef FULL_UI
            if (preview) SetWindowTextA(bar, a);
#endif
            draw(bar, FALSE);
        }
#endif
    }
#endif
}
static LRESULT CALLBACK wndproc(HWND w, UINT m, WPARAM wp, LPARAM lp) {
    if (m == taskbar_created && w == host) { trace("TaskbarCreated"); taskbar = NULL; attach(); return 0; }
    switch (m) {
    case WM_GETOBJECT: return 0;
#ifdef DISK_GPU
    case METRICS_READY: if (w == host) present_metrics(); return 0;
#endif

#ifdef BATTERY_ONLY
    case WM_TIMER:
        if (w == host) {
#ifdef P1_DIAGNOSTICS
            ULONGLONG now = GetTickCount64();
            if (previous_tick && now - previous_tick > 3000) trace("timer-gap-over-3s");
            previous_tick = now;
#endif
            ++timer_ticks; attach(); if (timer_ticks % 5 == 0) { layout(); trace("heartbeat"); } sample();
        }
        return 0;
    case WM_APP:
        if (worker) { CloseHandle(worker); worker = NULL; }
        last_poll_ok = incoming.found;
        if (incoming.found) { battery = incoming; last_good = GetTickCount64(); }
        sample();
        return 0;
#endif
#ifdef BATTERY_ONLY
    case WM_SETTINGCHANGE: case WM_THEMECHANGED:
        theme(); trace("theme-setting"); if (bar) InvalidateRect(bar, NULL, FALSE); return 0;
    case WM_DPICHANGED: case WM_DPICHANGED_AFTERPARENT:
        dpi = 0; layout(); trace("dpi-change"); if (bar) InvalidateRect(bar, NULL, FALSE); return 0;
#else
    case WM_SETTINGCHANGE: case WM_THEMECHANGED:
        theme(); trace("theme-setting"); if (bar) draw(bar, FALSE); return 0;
    case WM_DPICHANGED: case WM_DPICHANGED_AFTERPARENT:
        dpi = 0; layout(); trace("dpi-change"); if (bar) draw(bar, FALSE); return 0;
#endif
#ifdef P1_DIAGNOSTICS
    case WM_POWERBROADCAST:
        if (wp == PBT_APMSUSPEND) trace("power-suspend");
        else if (wp == PBT_APMRESUMEAUTOMATIC) trace("power-resume-auto");
        else if (wp == PBT_APMRESUMESUSPEND) trace("power-resume-user");
        return TRUE;
#endif
    case WM_ERASEBKGND: return 1;
#ifdef BATTERY_ONLY
    case WM_PAINT:
        if (w == bar) {
            PAINTSTRUCT ps;
            RECT r;
            HDC dc = BeginPaint(w, &ps);
            HGDIOBJ previous = font ? SelectObject(dc, font) : NULL;
            HBRUSH bg = CreateSolidBrush(preview ? (light ? RGB(245,245,245) : RGB(32,32,32)) : RGB(255,0,255));
            GetClientRect(w, &r); FillRect(dc, &r, bg); DeleteObject(bg);
            SetBkMode(dc, TRANSPARENT); SetTextColor(dc, light ? RGB(1,1,1) : RGB(255,255,255));
            r.left = MulDiv(4,dpi,96); r.top = (r.bottom - MulDiv(30,dpi,96))/2;
            TextOutA(dc, r.left, r.top, line1, lstrlenA(line1));
            TextOutA(dc, r.left, r.top + MulDiv(15,dpi,96), line2, lstrlenA(line2));
            if (previous) SelectObject(dc, previous);
            EndPaint(w, &ps); ++paint_count;
            return 0;
        }
        break;
#else
    case WM_PAINT:
        if (w == bar) {
            draw(w, TRUE);
            return 0;
        }
        break;
#endif
    case WM_CONTEXTMENU:
        if (w == bar) {
            POINT p;
            HMENU menu = CreatePopupMenu();
            int choice;
            GetCursorPos(&p);
#ifdef FULL_UI
            AppendMenuA(menu, MF_STRING, 1, "Move left 48 px");
            AppendMenuA(menu, MF_STRING, 2, "Move right 48 px");
#endif
            AppendMenuA(menu, MF_STRING, 3, "Exit");
            SetForegroundWindow(host);
            choice = TrackPopupMenu(menu, TPM_RETURNCMD | TPM_NONOTIFY | TPM_RIGHTBUTTON,
                p.x, p.y, 0, host, NULL);
            DestroyMenu(menu);
#ifdef FULL_UI
            if (choice == 1) offset_dip += 48;
            if (choice == 2 && offset_dip >= 48) offset_dip -= 48;
#endif
#ifdef BATTERY_ONLY
            if (choice == 3) PostMessageW(host, WM_CLOSE, 0, 0);
#else
            if (choice == 3) PostQuitMessage(0);
#endif
#if defined(FULL_UI) || defined(BATTERY_ONLY)
            layout();
#endif
            return 0;
        }
        break;
    case WM_CLOSE:
        if (w == host || preview) { PostQuitMessage(0); return 0; }
        break;
    case WM_DESTROY:
        /* Explorer may destroy only the child; the hidden host and its timer survive. */
        if (w == bar) { trace("bar-destroyed"); bar = NULL; }
        return 0;
    }
    return DefWindowProcA(w,m,wp,lp);
}
void __stdcall start(void) {
    WNDCLASSA wc = {0};
    MSG msg;
#ifdef BATTERY_ONLY
    HANDLE mutex;
#else
    HANDLE mutex, timer;
    LARGE_INTEGER due;
    unsigned layout_countdown = 5;
#endif
#ifdef BATTERY_ONLY
    {
        const CHAR *command = GetCommandLineA();
        const CHAR option[] = "--list";
        int n = lstrlenA(command), i;
        while (n && (command[n-1] == ' ' || command[n-1] == '\t')) --n;
        for (i = 0; i < 6 && n >= 6 && command[n-6+i] == option[i]; ++i) {}
        if (i == 6) ExitProcess(battery_list());
    }
#endif
    mutex = CreateMutexA(NULL, FALSE, "Local\\" CLASS);
    if (!mutex || GetLastError() == ERROR_ALREADY_EXISTS) ExitProcess(2);
    instance = GetModuleHandleA(NULL);
    ImmDisableIME((DWORD)-1);
#ifdef FULL_UI
    {
        const CHAR *command = GetCommandLineA();
        int n = lstrlenA(command);
        preview = n >= 9 && lstrcmpA(command + n - 9, "--preview") == 0;
    }
#endif
    wc.lpfnWndProc = wndproc; wc.hInstance = instance; wc.lpszClassName = CLASS;
    wc.hCursor = LoadCursorA(NULL, IDC_ARROW);
    if (!RegisterClassA(&wc)) ExitProcess(3);
    taskbar_created = RegisterWindowMessageA("TaskbarCreated");
    host = CreateWindowExA(WS_EX_TOOLWINDOW, CLASS, APP, WS_POPUP, 0,0,0,0,NULL,NULL,instance,NULL);
    if (!host) ExitProcess(4);
#ifdef DISK_GPU
    metrics_start(host);
#endif
    theme(); attach(); sample();
#ifdef BATTERY_ONLY
    if (!SetCoalescableTimer(host,1,1000,NULL,100)) ExitProcess(5);
    for (;;) {
        /* The widget has no hover interaction. Avoid waking for mouse-motion alone
           on Explorer's shared input queue; button clicks and sent messages still wake it. */
        MsgWaitForMultipleObjectsEx(0, NULL, INFINITE,
            QS_POSTMESSAGE | QS_TIMER | QS_PAINT | QS_SENDMESSAGE | QS_MOUSEBUTTON,
            MWMO_INPUTAVAILABLE);
        while (PeekMessageA(&msg, NULL, 0, 0, PM_REMOVE)) {
            if (msg.message == WM_QUIT) goto done;
            DispatchMessageA(&msg);
        }
    }
done:
    KillTimer(host,1);
#else
    due.QuadPart = -10000000;
    timer = CreateWaitableTimerA(NULL, FALSE, NULL);
    if (!SetWaitableTimerEx(timer, &due, 1000, NULL, NULL, NULL, 100)) ExitProcess(5);
    for (;;) {
        DWORD wait = MsgWaitForMultipleObjectsEx(1, &timer, INFINITE,
            QS_POSTMESSAGE | QS_TIMER | QS_PAINT | QS_SENDMESSAGE | QS_MOUSEBUTTON,
            MWMO_INPUTAVAILABLE);
        if (wait == WAIT_OBJECT_0) {
#ifdef P1_DIAGNOSTICS
            ULONGLONG now = GetTickCount64();
            if (previous_tick && now - previous_tick > 3000) trace("timer-gap-over-3s");
            previous_tick = now;
#endif
            ++timer_ticks;
            if (!--layout_countdown) {
                layout_countdown = 5;
                attach(); layout(); trace("heartbeat");
            } else if (!bar) attach();
            sample();
        } else if (wait != WAIT_OBJECT_0 + 1) break;
        else {
            if (PeekMessageA(&msg, NULL, 0, 0, PM_REMOVE)) {
                if (msg.message == WM_QUIT) goto done;
                DispatchMessageA(&msg);
            }
        }
    }
done:
    CloseHandle(timer);
#endif
#ifdef DISK_GPU
    metrics_stop();
#endif
    if (IsWindow(bar)) DestroyWindow(bar);
    DestroyWindow(host);
    if (font) DeleteObject(font);
    CloseHandle(mutex);
    ExitProcess(0);
}

