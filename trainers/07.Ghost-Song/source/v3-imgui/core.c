/*
 * Ghost Song Trainer v3 - core: version.dll proxy, logging, settings, feature table, hotkeys, start-up.
 *
 * UnityPlayer.dll imports VERSION.dll, so a version.dll placed next to GhostSong.exe is loaded first.
 * Every export is forwarded (a naked `jmp` through a table) to the real C:\Windows\System32\version.dll.
 */
#include <windows.h>
#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include "internal.h"
#include "MinHook.h"

char g_dir[MAX_PATH];
volatile LONG g_ft[FT__COUNT];
volatile LONG g_req[AC__COUNT];
Gs3Settings g_set = { 50000, 2.0f, 1.0f, 1, 9999999 };

static CRITICAL_SECTION g_cs;
static char  g_toast[160];
static DWORD g_toast_until;
static DWORD g_giveall_armed_until;
static int   g_cs_ready;

/* version.dll forwarding lives in proxy.c */
void proxy_load_real(void);

/* ------------------------------------------------------------------ logging / toast */
void gs3_log(const char *fmt, ...)
{
    if (!g_dir[0]) return;
    char line[1024];
    SYSTEMTIME t; GetLocalTime(&t);
    int p = snprintf(line, sizeof line, "[%02d:%02d:%02d.%03d] ", t.wHour, t.wMinute, t.wSecond, t.wMilliseconds);
    va_list ap; va_start(ap, fmt);
    vsnprintf(line + p, sizeof line - (size_t)p - 2, fmt, ap);
    va_end(ap);
    size_t l = strlen(line); line[l++] = '\n'; line[l] = 0;
    char path[MAX_PATH + 32]; snprintf(path, sizeof path, "%sgs3_trainer.log", g_dir);
    HANDLE f = CreateFileA(path, FILE_APPEND_DATA, FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (f != INVALID_HANDLE_VALUE) { DWORD w; WriteFile(f, line, (DWORD)l, &w, NULL); CloseHandle(f); }
}

void gs3_toast(const char *fmt, ...)
{
    char buf[160];
    va_list ap; va_start(ap, fmt); vsnprintf(buf, sizeof buf, fmt, ap); va_end(ap);
    if (g_cs_ready) EnterCriticalSection(&g_cs);
    strncpy(g_toast, buf, sizeof g_toast - 1); g_toast[sizeof g_toast - 1] = 0;
    g_toast_until = GetTickCount() + 2800;
    if (g_cs_ready) LeaveCriticalSection(&g_cs);
    gs3_log("toast: %s", buf);
}

int gs3_toast_get(char *buf, int cap)
{
    int rem = 0;
    EnterCriticalSection(&g_cs);
    DWORD now = GetTickCount();
    if ((int)(g_toast_until - now) > 0) { rem = (int)(g_toast_until - now); strncpy(buf, g_toast, (size_t)cap - 1); buf[cap - 1] = 0; }
    LeaveCriticalSection(&g_cs);
    return rem;
}

/* ------------------------------------------------------------------ settings (gs3_trainer.ini) */
static void ini_path(char *out, size_t cap) { snprintf(out, cap, "%sgs3_trainer.ini", g_dir); }

static float ini_float(const char *key, float def, const char *ini)
{
    char b[32], d[32]; snprintf(d, sizeof d, "%.2f", (double)def);
    GetPrivateProfileStringA("settings", key, d, b, sizeof b, ini);
    return (float)atof(b);
}

static void settings_load(void)
{
    char ini[MAX_PATH + 32]; ini_path(ini, sizeof ini);
    g_set.money_amount = (int)GetPrivateProfileIntA("settings", "money_amount", g_set.money_amount, ini);
    g_set.money_target = (int)GetPrivateProfileIntA("settings", "money_target", g_set.money_target, ini);
    g_set.hud_strip    = (int)GetPrivateProfileIntA("settings", "hud_strip", g_set.hud_strip, ini);
    g_set.speed_mult   = ini_float("speed_mult", g_set.speed_mult, ini);
    g_set.ui_scale     = ini_float("ui_scale", g_set.ui_scale, ini);
    if (g_set.money_amount < 1) g_set.money_amount = 1;
    if (g_set.money_amount > 1000000000) g_set.money_amount = 1000000000;
    if (g_set.money_target < 1000) g_set.money_target = 1000;
    if (g_set.money_target > 2000000000) g_set.money_target = 2000000000;
    if (g_set.speed_mult < 1.0f) g_set.speed_mult = 1.0f;
    if (g_set.speed_mult > 4.0f) g_set.speed_mult = 4.0f;
    if (g_set.ui_scale < 0.7f) g_set.ui_scale = 0.7f;
    if (g_set.ui_scale > 2.0f) g_set.ui_scale = 2.0f;
}

void gs3_settings_save(void)
{
    char ini[MAX_PATH + 32], v[32]; ini_path(ini, sizeof ini);
    snprintf(v, sizeof v, "%d", g_set.money_amount); WritePrivateProfileStringA("settings", "money_amount", v, ini);
    snprintf(v, sizeof v, "%d", g_set.money_target); WritePrivateProfileStringA("settings", "money_target", v, ini);
    snprintf(v, sizeof v, "%d", g_set.hud_strip);    WritePrivateProfileStringA("settings", "hud_strip", v, ini);
    snprintf(v, sizeof v, "%.2f", (double)g_set.speed_mult); WritePrivateProfileStringA("settings", "speed_mult", v, ini);
    snprintf(v, sizeof v, "%.2f", (double)g_set.ui_scale);   WritePrivateProfileStringA("settings", "ui_scale", v, ini);
}

/* ------------------------------------------------------------------ feature table */
static const struct { const char *name, *key; } k_ft[FT__COUNT] = {
    { "God mode",                 "F1" },
    { "Unlimited money",          "F3" },
    { "Unlimited items",          "F3" },
    { "Keep permanent-stat items", "" },
    { "Unlimited jump",           "F4" },
    { "Move speed",               "F5" },
    { "One-hit kill",             "F6" },
    { "Infinite stamina + spirit", "F8" },
    { "Infinite ammo / no overheat", "" },
    { "Show all items on map",    "F9" },
};
static const struct { const char *name, *key; } k_ac[AC__COUNT] = {
    { "Add money",             "F2"  },
    { "Heal now",              "F7"  },
    { "Give all items",        "F11" },
    { "Unlock map chunks",     ""    },
    { "Write diagnostics",     "F12" },
};

int gs3_feature_get(int id) { return (id >= 0 && id < FT__COUNT) ? (int)g_ft[id] : 0; }
const char *gs3_feature_name(int id)   { return k_ft[id].name; }
const char *gs3_feature_hotkey(int id) { return k_ft[id].key; }
const char *gs3_action_name(int id)    { return k_ac[id].name; }
const char *gs3_action_hotkey(int id)  { return k_ac[id].key; }

int gs3_feature_status(int id)
{
    if (!g_hs_tick) return HS_NONE;
    if (g_hs_tick == HS_FAIL) return HS_FAIL;
    switch (id) {
    case FT_JUMP:   return g_hs_jump;
    case FT_SPEED:  return g_hs_clamp;
    case FT_OHK:    return g_hs_ohk;
    case FT_MAPALL: return g_hs_map;
    default:        return HS_OK;
    }
}

int gs3_action_status(int id)
{
    if (!g_hs_tick) return HS_NONE;
    if (g_hs_tick == HS_FAIL) return HS_FAIL;
    if (id == AC_HEAL) return g_hs_rest;
    return HS_OK;
}

void gs3_feature_set(int id, int on)
{
    if (id < 0 || id >= FT__COUNT) return;
    if (on && gs3_feature_status(id) != HS_OK) {
        gs3_toast("%s: not available (%s)", k_ft[id].name, g_hs_tick ? "hook missing" : "game not ready");
        return;
    }
    if ((int)g_ft[id] == (on ? 1 : 0)) return;
    InterlockedExchange(&g_ft[id], on ? 1 : 0);
    if (id == FT_SPEED && on) gs3_toast("%s x%.2g ON", k_ft[id].name, (double)g_set.speed_mult);
    else gs3_toast("%s %s", k_ft[id].name, on ? "ON" : "OFF");
}

void gs3_feature_toggle(int id) { gs3_feature_set(id, !gs3_feature_get(id)); }

int gs3_giveall_armed(void) { return (int)(g_giveall_armed_until - GetTickCount()) > 0; }

void gs3_action(int id)
{
    if (id < 0 || id >= AC__COUNT) return;
    if (gs3_action_status(id) != HS_OK) { gs3_toast("%s: not available", k_ac[id].name); return; }
    if (id == AC_GIVEALL) {                       /* two presses within 5 s (it changes the save) */
        if (!gs3_giveall_armed()) {
            g_giveall_armed_until = GetTickCount() + 5000;
            gs3_toast("GIVE ALL ITEMS: press again within 5 s to confirm (changes your save)");
            return;
        }
        g_giveall_armed_until = 0;
    }
    InterlockedIncrement(&g_req[id]);
}

/* ------------------------------------------------------------------ hotkeys */
static int game_is_foreground(void)
{
    HWND fg = GetForegroundWindow();
    if (!fg) return 0;
    DWORD pid = 0; GetWindowThreadProcessId(fg, &pid);
    return pid == GetCurrentProcessId();
}

static DWORD WINAPI hotkey_thread(LPVOID unused)
{
    (void)unused;
    static const int keys[] = { VK_F1, VK_F2, VK_F3, VK_F4, VK_F5, VK_F6, VK_F7, VK_F8, VK_F9, VK_F10, VK_F11, VK_F12, VK_INSERT };
    SHORT last[sizeof keys / sizeof keys[0]] = { 0 };
    for (;;) {
        Sleep(12);
        int fg = game_is_foreground();
        for (size_t i = 0; i < sizeof keys / sizeof keys[0]; i++) {
            SHORT s = GetAsyncKeyState(keys[i]);
            int down = (s & 0x8000) != 0;
            int edge = down && !last[i];
            last[i] = (SHORT)down;
            if (!edge || !fg) continue;
            switch (keys[i]) {
            case VK_F1:  gs3_feature_toggle(FT_GOD); break;
            case VK_F2:  gs3_action(AC_ADDMONEY); break;
            case VK_F3: {
                int on = !(gs3_feature_get(FT_MONEY) && gs3_feature_get(FT_ITEMS));
                gs3_feature_set(FT_MONEY, on); gs3_feature_set(FT_ITEMS, on);
                break; }
            case VK_F4:  gs3_feature_toggle(FT_JUMP); break;
            case VK_F5:  gs3_feature_toggle(FT_SPEED); break;
            case VK_F6:  gs3_feature_toggle(FT_OHK); break;
            case VK_F7:  gs3_action(AC_HEAL); break;
            case VK_F8:  gs3_feature_toggle(FT_STAMINA); break;
            case VK_F9:  gs3_feature_toggle(FT_MAPALL); break;
            case VK_F10: case VK_INSERT: gs3_overlay_menu_toggle(); break;
            case VK_F11: gs3_action(AC_GIVEALL); break;
            case VK_F12: gs3_action(AC_DIAG); break;
            }
        }
    }
}

/* ------------------------------------------------------------------ start-up */
void gs3_now_str(char *buf, int cap)
{
    SYSTEMTIME t; GetLocalTime(&t);
    snprintf(buf, (size_t)cap, "%04d-%02d-%02d %02d:%02d:%02d", t.wYear, t.wMonth, t.wDay, t.wHour, t.wMinute, t.wSecond);
}
int gs3_selftest_requested(void)
{
    char env[8] = { 0 };
    if (GetEnvironmentVariableA("TRAINER_SELFTEST", env, sizeof env) && env[0] == '1') return 1;
    char p[MAX_PATH + 32]; snprintf(p, sizeof p, "%sgs3_selftest.flag", g_dir);
    return GetFileAttributesA(p) != INVALID_FILE_ATTRIBUTES;
}

static DWORD WINAPI init_thread(LPVOID unused)
{
    (void)unused;
    gs3_log("==== Ghost Song Trainer %s starting (pid %lu) ====", GS3_VERSION, GetCurrentProcessId());
    MH_STATUS mh = MH_Initialize();
    if (mh != MH_OK) { gs3_log("MH_Initialize failed: %s", MH_StatusToString(mh)); return 1; }
    CreateThread(NULL, 0, hotkey_thread, NULL, 0, NULL);
    gs3_overlay_start();          /* independent of il2cpp: needs only d3d11 */
    int rc = game_init();         /* waits for il2cpp, resolves by name, installs hooks */
    gs3_log("game_init -> %d", rc);
    return 0;
}

BOOL WINAPI DllMain(HINSTANCE inst, DWORD reason, LPVOID reserved)
{
    (void)reserved;
    if (reason == DLL_PROCESS_ATTACH) {
        DisableThreadLibraryCalls(inst);
        InitializeCriticalSection(&g_cs); g_cs_ready = 1;
        proxy_load_real();
        char exe[MAX_PATH]; GetModuleFileNameA(NULL, exe, MAX_PATH);
        char *s = strrchr(exe, '\\');
        if (s) { s[1] = 0; strncpy(g_dir, exe, MAX_PATH - 1); }
        /* only inject into the game itself (the version.dll may also be loaded by e.g. UnityCrashHandler64) */
        const char *base = s ? s + 1 : exe;
        char name[MAX_PATH]; GetModuleFileNameA(NULL, name, MAX_PATH);
        const char *exeName = strrchr(name, '\\'); exeName = exeName ? exeName + 1 : name;
        (void)base;
        if (_stricmp(exeName, "GhostSong.exe") != 0) { g_dir[0] = 0; return TRUE; }
        settings_load();
        CreateThread(NULL, 0, init_thread, NULL, 0, NULL);
    }
    return TRUE;
}
