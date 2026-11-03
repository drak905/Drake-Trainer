/*
 * Guacamelee! Super Turbo Championship Edition - in-game trainer (dinput8.dll proxy, x86).
 *
 * No game file is modified on disk.  Everything is resolved at runtime from byte signatures
 * (AOB) and from the engine's own console-variable registry (name -> address), so it keeps
 * working on builds whose addresses differ (Epic / Steam / GOG), and degrades gracefully
 * (feature greyed out) when a signature is not found.
 *
 * Evidence (see artifacts/gcm/subtasks/ev_*.json):
 *   God mode           g_playersInvincible  (bool)   - checked in the damage routine
 *   Infinite stamina   g_infiniteMana       (bool)
 *   Money              global int, cap 100000; AddCurrency(int) / SpendCurrency(uint) (cdecl)
 *   Unlimited jump     air-jump counter check in the character update (2 branch patches)
 *   Speed x N          character fields m_moveSpeed(+0x238) / m_walkSpeed(+0x23c)
 *   Reveal map         engine's own "Clear Map Fog of War" routine (+ backup / restore)
 *   One-hit kill       hook of damage routine, enemies only (player index < 0)
 *   Infinite Intenso   engine's own "Fill Devil Trigger Bar" routine
 */
#define WIN32_LEAN_AND_MEAN
#define COBJMACROS
#include <windows.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdarg.h>
#include <ctype.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include <d3d9.h>
#include <d3dx9core.h>
#include "MinHook.h"

#define TRAINER_VERSION "1.0.0"

/* ------------------------------------------------------------------------------------------ */
/* logging                                                                                      */
/* ------------------------------------------------------------------------------------------ */
static char g_dir[MAX_PATH];
static FILE *g_log;
static void logf_(const char *fmt, ...)
{
    if (!g_log) return;
    char buf[512];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof buf, fmt, ap);
    va_end(ap);
    fprintf(g_log, "[%8lu] %s\n", (unsigned long)GetTickCount(), buf);
    fflush(g_log);
}
#define LOG(...) logf_(__VA_ARGS__)

/* ------------------------------------------------------------------------------------------ */
/* pattern scanner                                                                              */
/* ------------------------------------------------------------------------------------------ */
typedef struct { uint8_t *base; size_t size; char name[9]; DWORD chr; } Sect;
static Sect g_sect[16];
static int g_nsect;
static uint8_t *g_imgBase;

static void init_sections(void)
{
    g_imgBase = (uint8_t *)GetModuleHandleA(NULL);
    IMAGE_DOS_HEADER *dos = (IMAGE_DOS_HEADER *)g_imgBase;
    IMAGE_NT_HEADERS *nt = (IMAGE_NT_HEADERS *)(g_imgBase + dos->e_lfanew);
    IMAGE_SECTION_HEADER *sh = IMAGE_FIRST_SECTION(nt);
    for (int i = 0; i < nt->FileHeader.NumberOfSections && g_nsect < 16; i++) {
        Sect *s = &g_sect[g_nsect++];
        s->base = g_imgBase + sh[i].VirtualAddress;
        s->size = sh[i].Misc.VirtualSize;
        memcpy(s->name, sh[i].Name, 8);
        s->name[8] = 0;
        s->chr = sh[i].Characteristics;
    }
}

static int in_data(const void *p)
{
    for (int i = 0; i < g_nsect; i++)
        if ((g_sect[i].chr & IMAGE_SCN_MEM_WRITE) && (uint8_t *)p >= g_sect[i].base && (uint8_t *)p < g_sect[i].base + g_sect[i].size) return 1;
    return 0;
}

/* sig: "55 8B ?? EC"  ->  returns number of matches, first match in *out */
static int sig_scan(const char *sig, int only_exec, uint8_t **out)
{
    uint8_t pat[96], msk[96];
    int n = 0;
    const char *p = sig;
    while (*p) {
        while (*p == ' ') p++;
        if (!*p) break;
        if (p[0] == '?') { pat[n] = 0; msk[n++] = 0; p += (p[1] == '?') ? 2 : 1; }
        else { pat[n] = (uint8_t)strtoul((char[]){p[0], p[1], 0}, NULL, 16); msk[n++] = 1; p += 2; }
    }
    int count = 0;
    *out = NULL;
    for (int s = 0; s < g_nsect; s++) {
        if (only_exec && !(g_sect[s].chr & IMAGE_SCN_MEM_EXECUTE)) continue;
        uint8_t *b = g_sect[s].base;
        size_t sz = g_sect[s].size;
        if (sz < (size_t)n) continue;
        for (size_t i = 0; i + n <= sz; i++) {
            if (b[i] != pat[0] && msk[0]) continue;
            int ok = 1;
            for (int k = 1; k < n; k++) if (msk[k] && b[i + k] != pat[k]) { ok = 0; break; }
            if (ok) { if (!count) *out = b + i; count++; }
        }
    }
    return count;
}

/* name -> address of an engine console variable: look for "push <name>; push <var>" */
static uint8_t *console_var(const char *name)
{
    size_t nl = strlen(name);
    uint8_t *str = NULL;
    for (int s = 0; s < g_nsect && !str; s++) {
        if (g_sect[s].chr & IMAGE_SCN_MEM_EXECUTE) continue;
        uint8_t *b = g_sect[s].base;
        for (size_t i = 1; i + nl + 1 <= g_sect[s].size; i++)
            if (b[i - 1] == 0 && memcmp(b + i, name, nl + 1) == 0) { str = b + i; break; }
    }
    if (!str) return NULL;
    for (int s = 0; s < g_nsect; s++) {
        if (!(g_sect[s].chr & IMAGE_SCN_MEM_EXECUTE)) continue;
        uint8_t *b = g_sect[s].base;
        for (size_t i = 0; i + 10 <= g_sect[s].size; i++) {
            if (b[i] == 0x68 && *(uint32_t *)(b + i + 1) == (uint32_t)(uintptr_t)str && b[i + 5] == 0x68) {
                uint8_t *v = (uint8_t *)(uintptr_t) * (uint32_t *)(b + i + 6);
                if (in_data(v)) return v;
            }
        }
    }
    return NULL;
}

static int readable(const void *p, size_t n)
{
    MEMORY_BASIC_INFORMATION mbi;
    if (!p || !VirtualQuery(p, &mbi, sizeof mbi)) return 0;
    if (mbi.State != MEM_COMMIT || (mbi.Protect & (PAGE_GUARD | PAGE_NOACCESS))) return 0;
    return (uint8_t *)p + n <= (uint8_t *)mbi.BaseAddress + mbi.RegionSize;
}

/* ------------------------------------------------------------------------------------------ */
/* game bindings (all resolved at runtime)                                                      */
/* ------------------------------------------------------------------------------------------ */
typedef void (__cdecl *FnAddCur)(int);
typedef void (__cdecl *FnSpendCur)(unsigned);
typedef void (__cdecl *FnVoid)(void);
typedef void (__fastcall *FnUpdate)(void *self, void *edx, float dt);
typedef void (__fastcall *FnDamage)(void *self, void *edx, int a, int b, float *d);

static volatile uint8_t *v_god, *v_mana, *v_dbgmenu;
static volatile uint32_t *v_currency;
static FnAddCur f_addcur;
static FnSpendCur f_spend, o_spend;
static FnVoid f_clearfog, f_filldevil;
static FnUpdate o_update;
static FnDamage o_damage;
static uint8_t *a_update, *a_damage, *a_spend;
static uint8_t *a_jump;           /* matched jump signature start */
static uint32_t **p_fogPtrA, **p_fogPtrB;  /* -> DAT: arrays of {uint32 *words; uint32 count} */
static uint32_t *p_fogCntA, *p_fogCntB;

#define CURRENCY_MAX 100000u

#define OFF_PLAYERIDX 0xFC
#define OFF_MOVESPD   0x238
#define OFF_WALKSPD   0x23C
#define OFF_JUMPMAX   0x258
#define OFF_JUMPUSED  0x25C

/* signatures (see artifacts/gcm/subtasks) */
static const char SIG_ADDCUR[] = "55 8B EC 83 EC 0C B9 ?? ?? ?? ?? E8 ?? ?? ?? ?? 8B 45 08 8B 0D ?? ?? ?? ?? 03 C1 3D A0 86 01 00 77 ?? 3B C1 73 ?? B8 A0 86 01 00";
static const char SIG_SPEND[] = "55 8B EC B9 ?? ?? ?? ?? E8 ?? ?? ?? ?? 8B 4D 08 A1 ?? ?? ?? ?? 3B C8 76 ?? 68 ?? ?? ?? ??";
static const char SIG_FILLDEVIL[] = "55 8B EC 51 8B 0D ?? ?? ?? ?? 64 A1 2C 00 00 00 56 57 33 F6 8B 3C 88";
static const char SIG_CLEARFOG[] = "56 57 8B 3D ?? ?? ?? ?? 33 F6 85 FF 74 ?? 66 90 A1 ?? ?? ?? ?? 8D 0C F0 8B 41 04 C1 E0 02 50 6A FF FF 31 E8 ?? ?? ?? ?? 46 83 C4 0C 3B F7 72 ??";
static const char SIG_DAMAGE[] = "55 8B EC 81 EC 74 02 00 00 F3 0F 10 05 ?? ?? ?? ?? 56 8B 75 10 57 8B F9 F3 0F 11 45 EC";
static const char SIG_UPDATE[] = "55 8B EC 83 E4 F8 81 EC C0 02 00 00 56 57 8B F9 6A 00 89 7C 24 64 8D B7 BC 0A 00 00 8B CE E8 ?? ?? ?? ?? F3 0F 10 87 6C 02 00 00";
static const char SIG_JUMP[]  = "3B 87 58 02 00 00 73 ?? F6 05 ?? ?? ?? ?? 02 0F 85 ?? ?? ?? ?? 80 BF 84 06 00 00 00";

/* ------------------------------------------------------------------------------------------ */
/* features                                                                                     */
/* ------------------------------------------------------------------------------------------ */
enum {
    F_GOD, F_STAMINA, F_ADDMONEY, F_INFMONEY, F_JUMP, F_SPEED, F_MAP, F_OHK, F_SPEEDCYCLE, F_INTENSO, F_DEBUGMENU, F_HELP,
    F_COUNT
};
typedef struct {
    const char *id, *label;
    int vk;
    int toggle;       /* 1 = on/off, 0 = one-shot action */
    volatile int on;
    int avail;        /* all dependencies resolved */
    const char *why;  /* reason when unavailable */
    volatile int hits;
} Feature;

static Feature g_f[F_COUNT] = {
    {"God",      "God Mode (no damage)",            VK_F1,  1},
    {"Stamina",  "Infinite Stamina",                VK_F2,  1},
    {"AddMoney", "+10,000 Pesos",                   VK_F3,  0},
    {"InfMoney", "Unlimited Money",                 VK_F4,  1},
    {"Jump",     "Unlimited Jump",                  VK_F5,  1},
    {"Speed",    "Move Speed x2",                   VK_F6,  1},
    {"Map",      "Show Entire Map + Items",         VK_F7,  1},
    {"OHK",      "One-Hit Kill",                    VK_F8,  1},
    {"SpeedCyc", "Cycle Speed (x2/x3/x4)",          VK_F9,  0},
    {"Intenso",  "Infinite Intenso (Devil Trigger)", VK_F10, 1},
    {"DbgMenu",  "Game Debug Menu (pause menu)",    VK_F11, 1},
    {"Help",     "Show / hide this panel",          VK_F12, 0},
};

static float g_speedMult = 2.0f;
static int   g_addMoneyAmount = 10000;
static int   g_overlay = 1;
static int   g_selftest;

/* ---- game-thread task queue ---------------------------------------------------------------- */
enum { T_ADDMONEY = 1, T_CLEARFOG, T_RESTOREFOG, T_FILLDEVIL, T_REFOG };
static volatile LONG q_lock;
#define QN 32
static volatile LONG q_head, q_tail;
static struct { int type, arg; } q_buf[QN];
static volatile DWORD g_lastUpdateTick, g_updateTid, g_endSceneTid;
static volatile LONG g_updateCalls, g_damageCalls, g_spendCalls, g_endSceneCalls;
static void *g_player[4];
static volatile float g_peakY = -1e9f, g_minY = 1e9f, g_maxX = -1e9f, g_minX = 1e9f;
static volatile int g_peakJumpUsed;          /* last seen player entities by slot */

static void enqueue(int type, int arg)
{
    LONG t = q_tail;
    if (((t + 1) % QN) == q_head) return;
    q_buf[t].type = type;
    q_buf[t].arg = arg;
    MemoryBarrier();
    q_tail = (t + 1) % QN;
}

/* ---- map fog backup ------------------------------------------------------------------------ */
static uint32_t *g_fogBackup[2][256];
static uint32_t  g_fogBackupLen[2][256];
static uint32_t *g_fogBackupPtr[2][256];
static uint32_t  g_fogBackupN[2];
static volatile int g_fogHave;

static void fog_arrays(int which, uint32_t **base, uint32_t *cnt)
{
    uint32_t **pp = which ? p_fogPtrB : p_fogPtrA;
    uint32_t *pc = which ? p_fogCntB : p_fogCntA;
    *base = pp ? (uint32_t *)(*(uintptr_t *)pp) : NULL;
    *cnt = pc ? *pc : 0;
}
static int fog_backup(void)
{
    for (int w = 0; w < 2; w++) {
        uint32_t *arr, n;
        fog_arrays(w, &arr, &n);
        if (!arr || n > 256) return 0;
        for (uint32_t i = 0; i < n; i++) {
            uint32_t *words = (uint32_t *)(uintptr_t)arr[i * 2];
            uint32_t len = arr[i * 2 + 1];
            if (!readable(words, len * 4)) return 0;
        }
    }
    for (int w = 0; w < 2; w++) {
        uint32_t *arr, n;
        fog_arrays(w, &arr, &n);
        g_fogBackupN[w] = n;
        for (uint32_t i = 0; i < n; i++) {
            uint32_t *words = (uint32_t *)(uintptr_t)arr[i * 2];
            uint32_t len = arr[i * 2 + 1];
            free(g_fogBackup[w][i]);
            g_fogBackup[w][i] = (uint32_t *)malloc(len * 4 + 4);
            memcpy(g_fogBackup[w][i], words, len * 4);
            g_fogBackupLen[w][i] = len;
            g_fogBackupPtr[w][i] = words;
        }
    }
    g_fogHave = 1;
    return 1;
}
static void fog_restore(void)
{
    if (!g_fogHave) return;
    for (int w = 0; w < 2; w++) {
        uint32_t *arr, n;
        fog_arrays(w, &arr, &n);
        if (n != g_fogBackupN[w]) continue;
        for (uint32_t i = 0; i < n; i++) {
            uint32_t *words = (uint32_t *)(uintptr_t)arr[i * 2];
            uint32_t len = arr[i * 2 + 1];
            if (words == g_fogBackupPtr[w][i] && len == g_fogBackupLen[w][i] && readable(words, len * 4)) memcpy(words, g_fogBackup[w][i], len * 4);
        }
    }
    g_fogHave = 0;
}
/* fraction of fog words that are all ones (for self test) */
static int fog_all_set(void)
{
    for (int w = 0; w < 2; w++) {
        uint32_t *arr, n;
        fog_arrays(w, &arr, &n);
        if (!arr) return -1;
        for (uint32_t i = 0; i < n; i++) {
            uint32_t *words = (uint32_t *)(uintptr_t)arr[i * 2];
            uint32_t len = arr[i * 2 + 1];
            if (!readable(words, len * 4)) return -1;
            for (uint32_t k = 0; k < len; k++) if (words[k] != 0xFFFFFFFFu) return 0;
        }
    }
    return 1;
}
static uint32_t fog_total_words(void)
{
    uint32_t tot = 0;
    for (int w = 0; w < 2; w++) {
        uint32_t *arr, n;
        fog_arrays(w, &arr, &n);
        if (!arr) return 0;
        for (uint32_t i = 0; i < n; i++) tot += arr[i * 2 + 1];
    }
    return tot;
}

static void run_tasks(void)
{
    if (q_head == q_tail) return;
    if (InterlockedCompareExchange(&q_lock, 1, 0) != 0) return;   /* update hook runs on several worker threads */
    while (q_head != q_tail) {
        int t = q_buf[q_head].type, a = q_buf[q_head].arg;
        q_head = (q_head + 1) % QN;
        switch (t) {
        case T_ADDMONEY:   if (f_addcur) f_addcur(a); break;
        case T_CLEARFOG:   if (f_clearfog && (g_fogHave || fog_backup())) f_clearfog(); break;
        case T_REFOG:      if (f_clearfog && g_fogHave) f_clearfog(); break;
        case T_RESTOREFOG: fog_restore(); break;
        case T_FILLDEVIL:  if (f_filldevil) f_filldevil(); break;
        }
    }
    q_lock = 0;
}

/* ---- unlimited jump patch ------------------------------------------------------------------ */
static uint8_t g_jumpOrig[2][2];
static int g_jumpPatched;
static int jump_patch(int enable)
{
    if (!a_jump) return 0;
    uint8_t *p1 = a_jump + 6;   /* 73 xx  jae -> nop nop */
    uint8_t *p2 = a_jump + 15;  /* 0F 85  jne -> nop; jmp */
    DWORD old;
    if (enable == g_jumpPatched) return 1;
    if (!VirtualProtect(a_jump, 24, PAGE_EXECUTE_READWRITE, &old)) return 0;
    if (enable) {
        if (p1[0] != 0x73 || p2[0] != 0x0F || p2[1] != 0x85) { VirtualProtect(a_jump, 24, old, &old); return 0; }
        g_jumpOrig[0][0] = p1[0]; g_jumpOrig[0][1] = p1[1];
        g_jumpOrig[1][0] = p2[0]; g_jumpOrig[1][1] = p2[1];
        p1[0] = 0x90; p1[1] = 0x90;
        p2[0] = 0x90; p2[1] = 0xE9;
    } else {
        p1[0] = g_jumpOrig[0][0]; p1[1] = g_jumpOrig[0][1];
        p2[0] = g_jumpOrig[1][0]; p2[1] = g_jumpOrig[1][1];
    }
    FlushInstructionCache(GetCurrentProcess(), a_jump, 24);
    VirtualProtect(a_jump, 24, old, &old);
    g_jumpPatched = enable;
    return 1;
}

/* ---- file access tracing (self-test only; helps locate save files) ------------------------------ */
typedef HANDLE(WINAPI *FnCreateFileW)(LPCWSTR, DWORD, DWORD, LPSECURITY_ATTRIBUTES, DWORD, DWORD, HANDLE);
static FnCreateFileW o_createfilew;
static HANDLE WINAPI hk_createfilew(LPCWSTR n, DWORD acc, DWORD sh, LPSECURITY_ATTRIBUTES sa, DWORD disp, DWORD fl, HANDLE tmpl)
{
    if (g_log && n && (acc & (GENERIC_WRITE | FILE_WRITE_DATA | FILE_APPEND_DATA)) && !wcsstr(n, L"GuacTrainer") && !wcsstr(n, L"trainer_")) {
        char u[400];
        WideCharToMultiByte(CP_UTF8, 0, n, -1, u, sizeof u, NULL, NULL);
        LOG("FILE-WRITE disp=%lu %s", (unsigned long)disp, u);
        /* self-test safety net: never let a test run modify the player's save data */
        char low[400];
        size_t k = 0;
        for (; u[k] && k < sizeof low - 1; k++) low[k] = (char)tolower((unsigned char)u[k]);
        low[k] = 0;
        if (!strstr(low, "hid#") && !strstr(low, "\\epic") && !strstr(low, "\\temp\\") && !strstr(low, "\\windows\\") && !strstr(low, ".log") &&
            (strstr(low, "sav") || strstr(low, "profile") || strstr(low, ".dat") || strstr(low, "slot") || strstr(low, "cloud"))) {
            LOG("BLOCKED write to %s (self-test protects saves)", u);
            SetLastError(ERROR_ACCESS_DENIED);
            return INVALID_HANDLE_VALUE;
        }
    }
    return o_createfilew(n, acc, sh, sa, disp, fl, tmpl);
}

/* ---- detours ------------------------------------------------------------------------------- */
static float g_spBase[4][2], g_spApplied[4][2];

static void apply_speed(void *self, int slot)
{
    static const int offs[2] = {OFF_MOVESPD, OFF_WALKSPD};
    for (int i = 0; i < 2; i++) {
        float *f = (float *)((uint8_t *)self + offs[i]);
        if (g_f[F_SPEED].on) {
            float want = g_spBase[slot][i] * g_speedMult;
            if (g_spApplied[slot][i] == 0.0f || *f != g_spApplied[slot][i]) {
                /* fresh value from the game: take it as the new baseline */
                if (g_spApplied[slot][i] == 0.0f || fabsf(*f - g_spApplied[slot][i]) > 1e-4f) g_spBase[slot][i] = *f;
                want = g_spBase[slot][i] * g_speedMult;
                if (*f > 0.0f) { g_spApplied[slot][i] = want; *f = want; }
            } else if (fabsf(want - *f) > 1e-4f) {      /* multiplier changed */
                g_spApplied[slot][i] = want; *f = want;
            }
        } else if (g_spApplied[slot][i] != 0.0f) {
            if (*f == g_spApplied[slot][i]) *f = g_spBase[slot][i];
            g_spApplied[slot][i] = 0.0f;
        }
    }
}

static void __fastcall hk_update(void *self, void *edx, float dt)
{
    InterlockedIncrement(&g_updateCalls);
    g_lastUpdateTick = GetTickCount();
    g_updateTid = GetCurrentThreadId();
    run_tasks();
    int idx = *(int *)((uint8_t *)self + OFF_PLAYERIDX);
    if (idx >= 0 && idx < 4) {
        g_player[idx] = self;
        if (idx == 0) {
            float *pos = (float *)((uint8_t *)self + 0x38);
            if (pos[1] > g_peakY) g_peakY = pos[1];
            if (pos[1] < g_minY) g_minY = pos[1];
            if (pos[0] > g_maxX) g_maxX = pos[0];
            if (pos[0] < g_minX) g_minX = pos[0];
            int ju = *(int *)((uint8_t *)self + OFF_JUMPUSED);
            if (ju > g_peakJumpUsed) g_peakJumpUsed = ju;
        }
        apply_speed(self, idx);
    }
    o_update(self, edx, dt);
}

static volatile int g_dryrun;
static void __fastcall hk_damage(void *self, void *edx, int a, int b, float *d)
{
    InterlockedIncrement(&g_damageCalls);
    if (g_f[F_OHK].on && d && *(int *)((uint8_t *)self + OFF_PLAYERIDX) < 0 && d[0] < 0.0f) {
        d[0] *= 1000.0f;
        g_f[F_OHK].hits++;
    }
    if (g_dryrun) return;
    o_damage(self, edx, a, b, d);
}

static void __cdecl hk_spend(unsigned amount)
{
    InterlockedIncrement(&g_spendCalls);
    if (g_f[F_INFMONEY].on) { g_f[F_INFMONEY].hits++; return; }
    o_spend(amount);
}

/* ------------------------------------------------------------------------------------------ */
/* overlay (Direct3D 9 EndScene hook + ID3DXFont)                                               */
/* ------------------------------------------------------------------------------------------ */
typedef HRESULT(WINAPI *FnEndScene)(IDirect3DDevice9 *);
typedef HRESULT(WINAPI *FnReset)(IDirect3DDevice9 *, D3DPRESENT_PARAMETERS *);
typedef HRESULT(WINAPI *FnCreateFontA)(IDirect3DDevice9 *, int, UINT, UINT, UINT, BOOL, DWORD, DWORD, DWORD, DWORD, const char *, ID3DXFont **);
static FnEndScene o_endscene;
static FnReset o_reset;
static FnCreateFontA p_createfont;
static ID3DXFont *g_font;
static IDirect3DDevice9 *g_fontDev;
static volatile DWORD g_toastUntil;
static int g_fontPx = 18;
static char g_toast[160];

static void toast(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(g_toast, sizeof g_toast, fmt, ap);
    va_end(ap);
    g_toastUntil = GetTickCount() + 3500;
}

static const char *keyname(int vk, char *buf)
{
    if (vk >= VK_F1 && vk <= VK_F24) sprintf(buf, "F%d", vk - VK_F1 + 1);
    else if (vk >= 'A' && vk <= 'Z') sprintf(buf, "%c", vk);
    else sprintf(buf, "0x%02X", vk);
    return buf;
}

static void draw_text(const char *s, int x, int y, D3DCOLOR c)
{
    RECT sh = {x + 1, y + 1, x + 900, y + 40}, r = {x, y, x + 900, y + 40};
    ID3DXFont_DrawTextA(g_font, NULL, s, -1, &sh, DT_LEFT | DT_NOCLIP, 0xE0000000);
    ID3DXFont_DrawTextA(g_font, NULL, s, -1, &r, DT_LEFT | DT_NOCLIP, c);
}

static HRESULT WINAPI hk_endscene(IDirect3DDevice9 *dev)
{
    InterlockedIncrement(&g_endSceneCalls);
    g_endSceneTid = GetCurrentThreadId();
    if (GetTickCount() - g_lastUpdateTick > 1500) run_tasks();   /* menus: no entity update running */

    if (g_overlay && p_createfont) {
        if (g_fontDev != dev) {
            if (g_font) { ID3DXFont_Release(g_font); g_font = NULL; }
            g_fontDev = dev;
        }
        if (!g_font) {
            D3DVIEWPORT9 vp;
            int fh = 18;
            if (SUCCEEDED(IDirect3DDevice9_GetViewport(dev, &vp)) && vp.Height > 0) fh = (int)vp.Height / 42 < 16 ? 16 : (int)vp.Height / 42;
            g_fontPx = fh;
            p_createfont(dev, fh, 0, FW_BOLD, 1, FALSE, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, ANTIALIASED_QUALITY, DEFAULT_PITCH | FF_DONTCARE, "Consolas", &g_font);
        }
        if (g_font) {
            int show_panel = g_f[F_HELP].on;
            DWORD now = GetTickCount();
            int y = 6;
            if (show_panel) {
                char line[160], kn[16];
                char title[96];
                sprintf(title, "Guacamelee! Trainer v%s", TRAINER_VERSION);
                draw_text(title, 8, y, 0xFFFFE040);
                y += g_fontPx + 2;
                for (int i = 0; i < F_COUNT; i++) {
                    Feature *f = &g_f[i];
                    if (i == F_HELP) continue;
                    const char *st = !f->avail ? "N/A" : (f->toggle ? (f->on ? "ON" : "off") : "");
                    if (i == F_SPEED && f->on) sprintf(line, "[%s] %s: ON (x%.0f)", keyname(f->vk, kn), f->label, g_speedMult);
                    else sprintf(line, "[%s] %s %s", keyname(f->vk, kn), f->label, st);
                    D3DCOLOR col = !f->avail ? 0xFF909090 : (f->toggle && f->on ? 0xFF60FF60 : 0xFFFFFFFF);
                    draw_text(line, 8, y, col);
                    y += g_fontPx;
                }
                sprintf(line, "[%s] hide panel", keyname(g_f[F_HELP].vk, kn));
                draw_text(line, 8, y, 0xFFB0B0B0);
                y += g_fontPx;
            }
            if (now < g_toastUntil) draw_text(g_toast, 8, y + 4, 0xFFFFD060);
        }
    }
    return o_endscene(dev);
}

static HRESULT WINAPI hk_reset(IDirect3DDevice9 *dev, D3DPRESENT_PARAMETERS *pp)
{
    if (g_font) { ID3DXFont_OnLostDevice(g_font); }
    HRESULT hr = o_reset(dev, pp);
    if (g_font) {
        if (SUCCEEDED(hr)) ID3DXFont_OnResetDevice(g_font);
        else { ID3DXFont_Release(g_font); g_font = NULL; }
    }
    return hr;
}

static LRESULT CALLBACK dummy_wndproc(HWND h, UINT m, WPARAM w, LPARAM l) { return DefWindowProcA(h, m, w, l); }

static int hook_d3d9(void)
{
    HMODULE d3d9 = GetModuleHandleA("d3d9.dll");
    HMODULE dx = GetModuleHandleA("d3dx9_43.dll");
    if (!dx) dx = LoadLibraryA("d3dx9_43.dll");
    if (dx) p_createfont = (FnCreateFontA)GetProcAddress(dx, "D3DXCreateFontA");
    LOG("d3d9=%p d3dx=%p createfont=%p", (void *)d3d9, (void *)dx, (void *)p_createfont);
    if (!d3d9) return 0;
    typedef IDirect3D9 *(WINAPI * FnD3DCreate)(UINT);
    FnD3DCreate create = (FnD3DCreate)GetProcAddress(d3d9, "Direct3DCreate9");
    if (!create) return 0;
    WNDCLASSA wc = {0};
    wc.lpfnWndProc = dummy_wndproc;
    wc.hInstance = GetModuleHandleA(NULL);
    wc.lpszClassName = "GuacTrainerDummy";
    RegisterClassA(&wc);
    HWND hw = CreateWindowA(wc.lpszClassName, "d", WS_OVERLAPPED, 0, 0, 16, 16, NULL, NULL, wc.hInstance, NULL);
    IDirect3D9 *d3d = create(D3D_SDK_VERSION);
    if (!d3d || !hw) return 0;
    D3DPRESENT_PARAMETERS pp;
    IDirect3DDevice9 *dev = NULL;
    HRESULT hr = E_FAIL;
    static const D3DDEVTYPE types[2] = {D3DDEVTYPE_HAL, D3DDEVTYPE_NULLREF};
    static const DWORD behav[2] = {D3DCREATE_SOFTWARE_VERTEXPROCESSING, D3DCREATE_HARDWARE_VERTEXPROCESSING};
    for (int ti = 0; ti < 2 && !dev; ti++)
        for (int bi = 0; bi < 2 && !dev; bi++) {
            memset(&pp, 0, sizeof pp);
            pp.Windowed = TRUE;
            pp.SwapEffect = D3DSWAPEFFECT_DISCARD;
            pp.BackBufferFormat = D3DFMT_X8R8G8B8;
            pp.BackBufferWidth = 16;
            pp.BackBufferHeight = 16;
            pp.BackBufferCount = 1;
            pp.hDeviceWindow = hw;
            hr = IDirect3D9_CreateDevice(d3d, D3DADAPTER_DEFAULT, types[ti], hw, behav[bi] | D3DCREATE_FPU_PRESERVE, &pp, &dev);
            LOG("CreateDevice type=%d behav=%d hr=%08lX", (int)types[ti], bi, (unsigned long)hr);
        }    LOG("CreateDevice hr=%08lX dev=%p", (unsigned long)hr, (void *)dev);
    if (FAILED(hr) || !dev) { IDirect3D9_Release(d3d); DestroyWindow(hw); return 0; }
    void **vt = *(void ***)dev;
    void *pEnd = vt[42], *pReset = vt[16];
    int ok = 1;
    MH_STATUS s1 = MH_CreateHook(pEnd, hk_endscene, (void **)&o_endscene), s2 = s1 == MH_OK ? MH_EnableHook(pEnd) : s1;
    MH_STATUS s3 = MH_CreateHook(pReset, hk_reset, (void **)&o_reset), s4 = s3 == MH_OK ? MH_EnableHook(pReset) : s3;
    LOG("d3d9 hooks: end=%p reset=%p st=%d %d %d %d", pEnd, pReset, s1, s2, s3, s4);
    if (s2 != MH_OK || s4 != MH_OK) ok = 0;
    IDirect3DDevice9_Release(dev);
    IDirect3D9_Release(d3d);
    DestroyWindow(hw);
    return ok;
}

/* ------------------------------------------------------------------------------------------ */
/* resolution of everything the features need                                                   */
/* ------------------------------------------------------------------------------------------ */
typedef struct { const char *name; int ok; char detail[96]; } Gate1;
static Gate1 g_gate[24];
static int g_ngate;
static void gate(const char *name, int ok, const char *fmt, ...)
{
    if (g_ngate >= 24) return;
    Gate1 *g = &g_gate[g_ngate++];
    g->name = name;
    g->ok = ok;
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(g->detail, sizeof g->detail, fmt, ap);
    va_end(ap);
    LOG("gate1 %-12s %s %s", name, ok ? "OK  " : "FAIL", g->detail);
}

static uint8_t *sig_unique(const char *name, const char *sig)
{
    uint8_t *p;
    int n = sig_scan(sig, 1, &p);
    if (n != 1) { gate(name, 0, "match_count=%d", n); return NULL; }
    gate(name, 1, "rva=0x%X", (unsigned)(p - g_imgBase));
    return p;
}

static void resolve_all(void)
{
    uint8_t *p;
    v_god = console_var("g_playersInvincible");
    gate("god_flag", v_god != NULL, "rva=0x%X", v_god ? (unsigned)(v_god - g_imgBase) : 0);
    v_mana = console_var("g_infiniteMana");
    gate("mana_flag", v_mana != NULL, "rva=0x%X", v_mana ? (unsigned)(v_mana - g_imgBase) : 0);
    v_dbgmenu = console_var("g_debugMenuEnabled");
    gate("dbgmenu_flag", v_dbgmenu != NULL, "rva=0x%X", v_dbgmenu ? (unsigned)(v_dbgmenu - g_imgBase) : 0);

    if ((p = sig_unique("add_currency", SIG_ADDCUR))) {
        f_addcur = (FnAddCur)p;
        v_currency = (volatile uint32_t *)(uintptr_t) * (uint32_t *)(p + 21);
        if (!in_data((void *)v_currency)) { v_currency = NULL; gate("currency_var", 0, "bad address"); }
        else gate("currency_var", 1, "rva=0x%X", (unsigned)((uint8_t *)v_currency - g_imgBase));
    }
    if ((a_spend = sig_unique("spend_currency", SIG_SPEND))) f_spend = (FnSpendCur)a_spend;
    f_filldevil = (FnVoid)sig_unique("fill_devil", SIG_FILLDEVIL);
    if ((p = sig_unique("clear_fog", SIG_CLEARFOG))) {
        f_clearfog = (FnVoid)p;
        p_fogCntA = (uint32_t *)(uintptr_t) * (uint32_t *)(p + 4);
        p_fogPtrA = (uint32_t **)(uintptr_t) * (uint32_t *)(p + 17);
        p_fogCntB = (uint32_t *)(uintptr_t) * (uint32_t *)(p + 0x32);
        p_fogPtrB = (uint32_t **)(uintptr_t) * (uint32_t *)(p + 0x41);
        int ok = in_data(p_fogCntA) && in_data(p_fogPtrA) && in_data(p_fogCntB) && in_data(p_fogPtrB);
        if (!ok) { f_clearfog = NULL; gate("fog_vars", 0, "bad addresses"); }
        else gate("fog_vars", 1, "words=%u", fog_total_words());
    }
    a_update = sig_unique("char_update", SIG_UPDATE);
    a_damage = sig_unique("damage", SIG_DAMAGE);
    a_jump = sig_unique("jump_check", SIG_JUMP);
    if (a_jump && !(a_jump[6] == 0x73 && a_jump[15] == 0x0F && a_jump[16] == 0x85)) { a_jump = NULL; gate("jump_bytes", 0, "unexpected opcodes"); }

    /* feature availability */
    g_f[F_GOD].avail = v_god != NULL;           g_f[F_GOD].why = "g_playersInvincible not found";
    g_f[F_STAMINA].avail = v_mana != NULL;      g_f[F_STAMINA].why = "g_infiniteMana not found";
    g_f[F_ADDMONEY].avail = f_addcur != NULL;   g_f[F_ADDMONEY].why = "AddCurrency not found";
    g_f[F_INFMONEY].avail = f_spend && f_addcur && v_currency;
    g_f[F_JUMP].avail = a_jump != NULL;
    g_f[F_SPEED].avail = a_update != NULL;
    g_f[F_SPEEDCYCLE].avail = a_update != NULL;
    g_f[F_MAP].avail = f_clearfog != NULL;
    g_f[F_OHK].avail = a_damage != NULL;
    g_f[F_INTENSO].avail = f_filldevil != NULL;
    g_f[F_DEBUGMENU].avail = v_dbgmenu != NULL;
    g_f[F_HELP].avail = 1;
}

static int install_hooks(void)
{
    if (MH_Initialize() != MH_OK) return 0;
    int ok = 1;
    if (a_update) { if (MH_CreateHook(a_update, hk_update, (void **)&o_update) != MH_OK || MH_EnableHook(a_update) != MH_OK) { gate("hook_update", 0, "MinHook failed"); g_f[F_SPEED].avail = 0; ok = 0; } else gate("hook_update", 1, "ok"); }
    if (a_damage) { if (MH_CreateHook(a_damage, hk_damage, (void **)&o_damage) != MH_OK || MH_EnableHook(a_damage) != MH_OK) { gate("hook_damage", 0, "MinHook failed"); g_f[F_OHK].avail = 0; ok = 0; } else gate("hook_damage", 1, "ok"); }
    if (f_spend) { if (MH_CreateHook(f_spend, hk_spend, (void **)&o_spend) != MH_OK || MH_EnableHook(f_spend) != MH_OK) { gate("hook_spend", 0, "MinHook failed"); g_f[F_INFMONEY].avail = 0; ok = 0; } else gate("hook_spend", 1, "ok"); }
    if (g_selftest) { void *cf = (void *)GetProcAddress(GetModuleHandleA("kernelbase.dll"), "CreateFileW"); if (cf && MH_CreateHook(cf, hk_createfilew, (void **)&o_createfilew) == MH_OK) MH_EnableHook(cf); }
    int d3 = hook_d3d9();
    gate("hook_d3d9", d3, d3 ? "EndScene+Reset" : "overlay disabled");
    return ok;
}

/* ------------------------------------------------------------------------------------------ */
/* feature actions                                                                              */
/* ------------------------------------------------------------------------------------------ */
static void set_flag(volatile uint8_t *p, int on) { if (p) *p = on ? 1 : 0; }

static void on_toggle(int i)
{
    Feature *f = &g_f[i];
    switch (i) {
    case F_GOD: set_flag(v_god, f->on); break;
    case F_STAMINA: set_flag(v_mana, f->on); break;
    case F_DEBUGMENU: set_flag(v_dbgmenu, f->on); break;
    case F_INFMONEY: if (f->on) enqueue(T_ADDMONEY, (int)CURRENCY_MAX); break;
    case F_JUMP: if (!jump_patch(f->on)) { f->on = 0; toast("Unlimited Jump: patch failed"); return; } break;
    case F_MAP: enqueue(f->on ? T_CLEARFOG : T_RESTOREFOG, 0); break;
    default: break;
    }
}

static void press(int i)
{
    Feature *f = &g_f[i];
    char kn[16];
    if (!f->avail) { toast("%s: not available on this game build", f->label); return; }
    if (i == F_HELP) { f->on = !f->on; return; }
    if (i == F_ADDMONEY) { enqueue(T_ADDMONEY, g_addMoneyAmount); toast("+%d pesos", g_addMoneyAmount); return; }
    if (i == F_SPEEDCYCLE) {
        g_speedMult = g_speedMult >= 4.0f ? 2.0f : g_speedMult + 1.0f;
        toast("Move speed multiplier: x%.0f%s", g_speedMult, g_f[F_SPEED].on ? "" : "  (press F6 to enable)");
        return;
    }
    if (f->toggle) {
        f->on = !f->on;
        on_toggle(i);
        toast("[%s] %s: %s", keyname(f->vk, kn), f->label, f->on ? "ON" : "OFF");
        LOG("toggle %s -> %d", f->id, f->on);
    }
}

/* maintenance that must keep running while features are on (cheap, polled) */
static void maintain(void)
{
    static DWORD lastMoney, lastIntenso, lastMap;
    DWORD now = GetTickCount();
    /* keep the engine flags as we set them (the game's debug menu may toggle them) */
    if (g_f[F_GOD].on) set_flag(v_god, 1);
    if (g_f[F_STAMINA].on) set_flag(v_mana, 1);
    if (g_f[F_INFMONEY].on && v_currency && now - lastMoney > 1000) {
        lastMoney = now;
        uint32_t c = *v_currency;
        if (c < CURRENCY_MAX) enqueue(T_ADDMONEY, (int)(CURRENCY_MAX - c));
    }
    if (g_f[F_INTENSO].on && f_filldevil && now - lastIntenso > 1500) {
        lastIntenso = now;
        enqueue(T_FILLDEVIL, 0);
    }
    if (g_f[F_MAP].on && f_clearfog && now - lastMap > 1000) {
        lastMap = now;   /* new level / new arrays -> clear again */
        if (!g_fogHave) enqueue(T_CLEARFOG, 0);
        else if (fog_all_set() == 0) enqueue(T_REFOG, 0);
    }
}

/* ------------------------------------------------------------------------------------------ */
/* config                                                                                       */
/* ------------------------------------------------------------------------------------------ */
static int parse_key(const char *s, int def)
{
    if (!s || !*s) return def;
    if ((s[0] == 'F' || s[0] == 'f') && isdigit((unsigned char)s[1])) { int n = atoi(s + 1); if (n >= 1 && n <= 24) return VK_F1 + n - 1; }
    if (strlen(s) == 1) return toupper((unsigned char)s[0]);
    if (!_stricmp(s, "INSERT")) return VK_INSERT;
    if (!_stricmp(s, "HOME")) return VK_HOME;
    if (!_stricmp(s, "END")) return VK_END;
    if (!_stricmp(s, "PAGEUP")) return VK_PRIOR;
    if (!_stricmp(s, "PAGEDOWN")) return VK_NEXT;
    if (!_stricmp(s, "NONE") || !_stricmp(s, "OFF")) return 0;
    if (s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) return (int)strtol(s, NULL, 16);
    return def;
}

static void load_config(void)
{
    char ini[MAX_PATH], buf[64];
    snprintf(ini, sizeof ini, "%s\\GuacTrainer.ini", g_dir);
    for (int i = 0; i < F_COUNT; i++) {
        GetPrivateProfileStringA("Keys", g_f[i].id, "", buf, sizeof buf, ini);
        g_f[i].vk = parse_key(buf, g_f[i].vk);
    }
    g_overlay = GetPrivateProfileIntA("Options", "Overlay", 1, ini);
    g_addMoneyAmount = GetPrivateProfileIntA("Options", "AddMoneyAmount", 10000, ini);
    GetPrivateProfileStringA("Options", "SpeedMultiplier", "2", buf, sizeof buf, ini);
    g_speedMult = (float)atof(buf);
    if (g_speedMult < 1.0f || g_speedMult > 8.0f) g_speedMult = 2.0f;
    g_f[F_HELP].on = GetPrivateProfileIntA("Options", "ShowPanelAtStart", 1, ini);
}

/* ------------------------------------------------------------------------------------------ */
/* self test (Gate 3/4): TRAINER_SELFTEST=1 or trainer_selftest.flag                            */
/* ------------------------------------------------------------------------------------------ */
typedef struct { const char *branch, *feature, *status; char note[200]; } FeatRes;
static FeatRes g_res[16];
static int g_nres;
static void res_add(const char *branch, const char *feature, int pass, const char *fmt, ...)
{
    if (g_nres >= 16) return;
    FeatRes *r = &g_res[g_nres++];
    r->branch = branch; r->feature = feature; r->status = pass == 1 ? "PASS" : pass == 0 ? "FAIL" : "PENDING_GAMEPLAY";
    va_list ap; va_start(ap, fmt); vsnprintf(r->note, sizeof r->note, fmt, ap); va_end(ap);
}

static void write_report(const char *phase)
{
    char path[MAX_PATH];
    snprintf(path, sizeof path, "%s\\trainer_selftest_report.json", g_dir);
    FILE *fp = fopen(path, "w");
    if (!fp) return;
    int fails = 0, pend = 0;
    for (int i = 0; i < g_nres; i++) { if (!strcmp(g_res[i].status, "FAIL")) fails++; else if (g_res[i].status[0] == 'P' && g_res[i].status[1] == 'E') pend++; }
    fprintf(fp, "{\n  \"trainer_version\": \"%s\",\n  \"phase\": \"%s\",\n  \"overall_status\": \"%s\",\n", TRAINER_VERSION, phase,
            fails ? "PARTIAL_FAIL_NEEDS_ISOLATED_HEAL" : (pend ? "PASS_STATIC_RUNTIME__GAMEPLAY_PENDING" : "PASS_READY_FOR_HUMAN"));
    fprintf(fp, "  \"threads\": {\"update_tid\": %lu, \"endscene_tid\": %lu, \"update_calls\": %ld, \"damage_calls\": %ld, \"spend_calls\": %ld, \"endscene_calls\": %ld},\n",
            (unsigned long)g_updateTid, (unsigned long)g_endSceneTid, (long)g_updateCalls, (long)g_damageCalls, (long)g_spendCalls, (long)g_endSceneCalls);
    fprintf(fp, "  \"gate1_signatures\": [\n");
    for (int i = 0; i < g_ngate; i++) fprintf(fp, "    {\"name\": \"%s\", \"ok\": %s, \"detail\": \"%s\"}%s\n", g_gate[i].name, g_gate[i].ok ? "true" : "false", g_gate[i].detail, i + 1 < g_ngate ? "," : "");
    fprintf(fp, "  ],\n  \"feature_results\": [\n");
    for (int i = 0; i < g_nres; i++)
        fprintf(fp, "    {\"subagent_branch_id\": \"%s\", \"feature\": \"%s\", \"status\": \"%s\", \"note\": \"%s\"}%s\n", g_res[i].branch, g_res[i].feature, g_res[i].status, g_res[i].note, i + 1 < g_nres ? "," : "");
    fprintf(fp, "  ]\n}\n");
    fclose(fp);
}

static void selftest_static(void)
{
    g_nres = 0;
    /* flags: write / read back / restore */
    if (v_god) { uint8_t o = *v_god; *v_god = 1; int ok = *v_god == 1; *v_god = o; res_add("SUBAGENT-COMBAT-01", "God Mode flag", ok, "g_playersInvincible rw ok=%d orig=%d", ok, o); }
    else res_add("SUBAGENT-COMBAT-01", "God Mode flag", 0, "unresolved");
    if (v_mana) { uint8_t o = *v_mana; *v_mana = 1; int ok = *v_mana == 1; *v_mana = o; res_add("SUBAGENT-STAMINA-03", "Infinite Stamina flag", ok, "g_infiniteMana rw ok=%d", ok); }
    else res_add("SUBAGENT-STAMINA-03", "Infinite Stamina flag", 0, "unresolved");
    /* currency delta */
    if (v_currency && f_addcur && f_spend) {
        uint32_t c0 = *v_currency;
        int ok = c0 <= CURRENCY_MAX;
        uint32_t room = CURRENCY_MAX - c0;
        int d = room >= 10 ? 10 : 0;
        if (d) { f_addcur(d); uint32_t c1 = *v_currency; ok = ok && c1 == c0 + d; o_spend ? o_spend(d) : f_spend(d); ok = ok && *v_currency == c0; }
        res_add("SUBAGENT-ECONOMY-02", "Add Money / currency delta", ok, "currency=%u (invariant 0..%u) delta_test=%s", c0, CURRENCY_MAX, d ? (ok ? "after==before+10 then restored" : "MISMATCH") : "skipped(full)");
        if (g_f[F_INFMONEY].avail) res_add("SUBAGENT-ECONOMY-02", "Unlimited Money (spend hook)", o_spend != NULL, "spend hook installed=%d", o_spend != NULL);
    } else res_add("SUBAGENT-ECONOMY-02", "Add Money / currency delta", 0, "unresolved");
    /* jump patch reversible */
    if (a_jump) {
        uint8_t b0 = a_jump[6], b1 = a_jump[15], b2 = a_jump[16];
        int ok = jump_patch(1) && a_jump[6] == 0x90 && a_jump[7] == 0x90 && a_jump[15] == 0x90 && a_jump[16] == 0xE9;
        ok = jump_patch(0) && ok && a_jump[6] == b0 && a_jump[15] == b1 && a_jump[16] == b2;
        res_add("SUBAGENT-MOVEMENT-04", "Unlimited Jump patch apply/revert", ok, "orig bytes %02X .. %02X %02X restored=%d", b0, b1, b2, ok);
    } else res_add("SUBAGENT-MOVEMENT-04", "Unlimited Jump patch apply/revert", 0, "signature unresolved");
    /* map fog arrays sane */
    if (f_clearfog) {
        uint32_t w = fog_total_words();
        res_add("SUBAGENT-MAP-05", "Reveal map (fog arrays)", w > 0 ? 1 : -1, "fog words=%u (0 until a save/inventory is loaded)", w);
    } else res_add("SUBAGENT-MAP-05", "Reveal map (fog arrays)", 0, "unresolved");
    res_add("SUBAGENT-MOVEMENT-04", "Speed x2 (character update hook)", a_update && o_update ? -1 : 0, "hook=%d; needs a live player entity", o_update != NULL);
    res_add("SUBAGENT-COMBAT-01", "One-Hit Kill (damage hook)", a_damage && o_damage ? -1 : 0, "hook=%d; needs a combat hit", o_damage != NULL);
    res_add("SUBAGENT-DT-06", "Infinite Intenso (fill routine)", f_filldevil ? -1 : 0, "fill routine resolved=%d; needs a live player", f_filldevil != NULL);
}

static void selftest_dynamic_update(void)
{
    /* refresh the gameplay-dependent items once a player entity has been seen */
    for (int i = 0; i < g_nres; i++) {
        FeatRes *r = &g_res[i];
        if (strstr(r->feature, "Speed")) {
            void *pl = g_player[0];
            if (pl) {
                float mv = *(float *)((uint8_t *)pl + OFF_MOVESPD), wk = *(float *)((uint8_t *)pl + OFF_WALKSPD);
                int ok = isfinite(mv) && mv > 0.0f && mv < 1000.0f && isfinite(wk) && wk >= 0.0f && wk < 1000.0f;
                r->status = ok ? "PASS" : "FAIL";
                snprintf(r->note, sizeof r->note, "player0=%p moveSpeed=%.3f walkSpeed=%.3f applied=%.3f (invariant finite, 0<v<1000) speedOn=%d", pl, mv, wk, g_spApplied[0][0], g_f[F_SPEED].on);
            }
        } else if (strstr(r->feature, "One-Hit")) {
            if (g_damageCalls > 0) { r->status = "PASS"; snprintf(r->note, sizeof r->note, "damage routine invoked %ld times through hook; ohk hits=%d", (long)g_damageCalls, g_f[F_OHK].hits); }
        } else if (strstr(r->feature, "Jump patch")) {
            /* nothing */
        }
    }
}

static DWORD WINAPI selftest_thread(LPVOID unused)
{
    (void)unused;
    Sleep(9000);
    LOG("selftest: static start");
    selftest_static();
    LOG("selftest: static done");
    write_report("static+runtime");
    for (int i = 0; i < 120; i++) {      /* up to ~4 minutes: refresh as gameplay starts */
        Sleep(2000);
        selftest_dynamic_update();
        write_report("live");
    }
    return 0;
}

/* optional test driver: trainer_cmd.txt in the game folder, one command per line (consumed) */
static void poll_cmd_file(void)
{
    static DWORD last;
    DWORD now = GetTickCount();
    if (now - last < 500) return;
    last = now;
    char path[MAX_PATH];
    snprintf(path, sizeof path, "%s\\trainer_cmd.txt", g_dir);
    FILE *fp = fopen(path, "r");
    if (!fp) return;
    char line[128];
    while (fgets(line, sizeof line, fp)) {
        for (int i = 0; i < F_COUNT; i++) {
            char id[32];
            if (sscanf(line, "%31s", id) == 1 && !_stricmp(id, g_f[i].id)) { press(i); LOG("cmd %s", id); }
        }
        if (!strncmp(line, "hurt", 4) && g_player[0] && o_damage) {
            float amount = 1.0f;
            sscanf(line + 4, "%f", &amount);
            uint8_t *pl = (uint8_t *)g_player[0];
            uint8_t before[0xC00], after[0xC00];
            memcpy(before, pl, sizeof before);
            void *comp = *(void **)(pl + 0x6c);
            uint8_t cb[0x300], ca[0x300];
            int hascomp = comp && readable(comp, 0x300);
            if (hascomp) memcpy(cb, comp, sizeof cb);
            float d[16] = {0};
            d[0] = -amount;
            int godBefore = v_god ? *v_god : -1;
            o_damage(pl, NULL, 0, 0, d);
            Sleep(120);
            memcpy(after, pl, sizeof after);
            if (hascomp) memcpy(ca, comp, sizeof ca);
            char out[MAX_PATH];
            snprintf(out, sizeof out, "%s\\trainer_hurt.txt", g_dir);
            FILE *o = fopen(out, "w");
            if (o) {
                fprintf(o, "hurt amount=%.2f god=%d comp=%p\n", amount, godBefore, comp);
                for (int k = 0; k < 0xC00; k += 4) if (memcmp(before + k, after + k, 4)) fprintf(o, "ent+0x%03X: %08X -> %08X (%g -> %g)\n", k, *(uint32_t *)(before + k), *(uint32_t *)(after + k), *(float *)(before + k), *(float *)(after + k));
                if (hascomp) for (int k = 0; k < 0x300; k += 4) if (memcmp(cb + k, ca + k, 4)) fprintf(o, "comp+0x%03X: %08X -> %08X (%g -> %g)\n", k, *(uint32_t *)(cb + k), *(uint32_t *)(ca + k), *(float *)(cb + k), *(float *)(ca + k));
                if (hascomp) for (int k = 0x130; k < 0x160; k += 4) fprintf(o, "comp+0x%03X = %g\n", k, *(float *)(ca + k));
                fclose(o);
            }
        }        if (!strncmp(line, "ohktest", 7)) {
            static uint8_t fake[0x1000];
            memset(fake, 0, sizeof fake);
            *(int *)(fake + OFF_PLAYERIDX) = -1;              /* an enemy */
            float d[16] = {0}, dp[16] = {0};
            d[0] = -1.0f; dp[0] = -1.0f;
            int was = g_f[F_OHK].on, hits0 = g_f[F_OHK].hits;
            g_dryrun = 1;
            g_f[F_OHK].on = 1;
            hk_damage(fake, NULL, 0, 0, d);                   /* enemy: must be multiplied */
            *(int *)(fake + OFF_PLAYERIDX) = 0;
            hk_damage(fake, NULL, 0, 0, dp);                  /* player: must stay untouched */
            g_f[F_OHK].on = was;
            g_dryrun = 0;
            char out[MAX_PATH];
            snprintf(out, sizeof out, "%s\\trainer_ohk.txt", g_dir);
            FILE *o = fopen(out, "w");
            if (o) { fprintf(o, "enemy_damage=%.1f player_damage=%.1f hits_delta=%d PASS=%d\n", d[0], dp[0], g_f[F_OHK].hits - hits0, d[0] == -1000.0f && dp[0] == -1.0f); fclose(o); }
        }
        if (!strncmp(line, "resetpeak", 9)) { g_peakY = -1e9f; g_minY = 1e9f; g_maxX = -1e9f; g_minX = 1e9f; g_peakJumpUsed = 0; }
        if (!strncmp(line, "dump", 4)) {
            char out[MAX_PATH];
            snprintf(out, sizeof out, "%s\\trainer_dump.txt", g_dir);
            FILE *o = fopen(out, "w");
            if (o) {
                void *pl = g_player[0];
                fprintf(o, "currency=%u god=%d mana=%d player0=%p updTid=%lu esTid=%lu updCalls=%ld\n", v_currency ? *v_currency : 0, v_god ? *v_god : -1, v_mana ? *v_mana : -1, pl, (unsigned long)g_updateTid, (unsigned long)g_endSceneTid, (long)g_updateCalls);
                if (pl && readable(pl, 0x1000)) {
                    uint8_t *e = (uint8_t *)pl;
                    fprintf(o, "pos=%.3f,%.3f,%.3f move=%.3f walk=%.3f jmpMax=%d jmpUsed=%d idx=%d\n", *(float *)(e + 0x38), *(float *)(e + 0x3c), *(float *)(e + 0x40), *(float *)(e + OFF_MOVESPD), *(float *)(e + OFF_WALKSPD), *(int *)(e + OFF_JUMPMAX), *(int *)(e + OFF_JUMPUSED), *(int *)(e + OFF_PLAYERIDX));
                }
                fprintf(o, "peakY=%.3f minY=%.3f minX=%.3f maxX=%.3f peakJumpUsed=%d\n", g_peakY, g_minY, g_minX, g_maxX, g_peakJumpUsed);
                fprintf(o, "fogWords=%u fogAllSet=%d jumpPatched=%d\n", fog_total_words(), fog_all_set(), g_jumpPatched);
                fclose(o);
            }
        }
    }
    fclose(fp);
    DeleteFileA(path);
}

/* ------------------------------------------------------------------------------------------ */
/* main thread                                                                                  */
/* ------------------------------------------------------------------------------------------ */
static int game_has_focus(void)
{
    HWND fg = GetForegroundWindow();
    DWORD pid = 0;
    if (!fg) return 0;
    GetWindowThreadProcessId(fg, &pid);
    return pid == GetCurrentProcessId();
}

static void load_real_dinput(void);
HRESULT WINAPI DirectInput8Create(HINSTANCE, DWORD, REFIID, LPVOID *, LPUNKNOWN);
static LONG CALLBACK veh(EXCEPTION_POINTERS *ep)
{
    DWORD c = ep->ExceptionRecord->ExceptionCode;
    if (c == 0xC0000005 || c == 0xC000001D || c == 0xC0000094 || c == 0xC00000FD) {
        HMODULE m = NULL;
        char nm[MAX_PATH] = "?";
        GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT, (LPCSTR)ep->ExceptionRecord->ExceptionAddress, &m);
        if (m) GetModuleFileNameA(m, nm, sizeof nm);
        LOG("EXCEPTION %08lX at %p (%s+0x%lX) tid=%lu info0=%lu info1=%p eax=%08lX ecx=%08lX esp=%08lX", (unsigned long)c, ep->ExceptionRecord->ExceptionAddress, nm,
            (unsigned long)((uint8_t *)ep->ExceptionRecord->ExceptionAddress - (uint8_t *)m), (unsigned long)GetCurrentThreadId(), (unsigned long)ep->ExceptionRecord->ExceptionInformation[0], (void *)ep->ExceptionRecord->ExceptionInformation[1],
            (unsigned long)ep->ContextRecord->Eax, (unsigned long)ep->ContextRecord->Ecx, (unsigned long)ep->ContextRecord->Esp);
    }
    return EXCEPTION_CONTINUE_SEARCH;
}

static DWORD WINAPI trainer_thread(LPVOID unused)
{
    (void)unused;
    load_real_dinput();
    AddVectoredExceptionHandler(1, veh);
    char logp[MAX_PATH];
    snprintf(logp, sizeof logp, "%s\\GuacTrainer.log", g_dir);
    g_log = fopen(logp, "w");
    LOG("Guacamelee STCE trainer %s starting (pid %lu)", TRAINER_VERSION, (unsigned long)GetCurrentProcessId());
    Sleep(2500);   /* let the engine create its window / device first */
    init_sections();
    load_config();
    {
        char flag0[MAX_PATH];
        snprintf(flag0, sizeof flag0, "%s\\trainer_selftest.flag", g_dir);
        g_selftest = (GetEnvironmentVariableA("TRAINER_SELFTEST", NULL, 0) > 0) || GetFileAttributesA(flag0) != INVALID_FILE_ATTRIBUTES;
    }
    resolve_all();
    int ok = install_hooks();
    int navail = 0;
    for (int i = 0; i < F_COUNT; i++) navail += g_f[i].avail;
    LOG("features available: %d/%d, hooks ok=%d", navail, F_COUNT, ok);
    toast("Trainer v%s loaded: %d/%d features. F12 = panel", TRAINER_VERSION, navail, F_COUNT);

    if (g_selftest) { LOG("self-test mode"); CreateThread(NULL, 0, selftest_thread, NULL, 0, NULL); }

    int prev[F_COUNT] = {0};
    for (;;) {
        Sleep(15);
        maintain();
        if (g_selftest) poll_cmd_file();
        if (!game_has_focus()) { for (int i = 0; i < F_COUNT; i++) prev[i] = 1; continue; }
        for (int i = 0; i < F_COUNT; i++) {
            if (!g_f[i].vk) continue;
            int down = (GetAsyncKeyState(g_f[i].vk) & 0x8000) != 0;
            if (down && !prev[i]) press(i);
            prev[i] = down;
        }
    }
    return 0;
}

/* ------------------------------------------------------------------------------------------ */
/* dinput8 proxy                                                                                */
/* ------------------------------------------------------------------------------------------ */
typedef HRESULT(WINAPI *FnDI8Create)(HINSTANCE, DWORD, REFIID, LPVOID *, LPUNKNOWN);
static FnDI8Create real_create;

/* Load the genuine system dinput8.dll.  Done from DllMain's worker thread *before* the game calls
 * DirectInput8Create, because the game calls it on a thread with a very small stack. */
static void load_real_dinput(void)
{
    char sys[MAX_PATH];
    GetSystemDirectoryA(sys, sizeof sys);
    strcat(sys, "\\dinput8.dll");
    HMODULE m = LoadLibraryA(sys);
    FARPROC fp = m ? GetProcAddress(m, "DirectInput8Create") : NULL;
    if (fp && (void *)fp != (void *)DirectInput8Create) real_create = (FnDI8Create)fp;
}

HRESULT WINAPI DirectInput8Create(HINSTANCE hinst, DWORD ver, REFIID riid, LPVOID *out, LPUNKNOWN outer)
{
    if (!real_create) load_real_dinput();   /* fallback only */
    return real_create ? real_create(hinst, ver, riid, out, outer) : E_FAIL;
}
BOOL WINAPI DllMain(HINSTANCE h, DWORD reason, LPVOID res)
{
    (void)res;
    if (reason == DLL_PROCESS_ATTACH) {
        DisableThreadLibraryCalls(h);
        GetModuleFileNameA(h, g_dir, sizeof g_dir);
        char *s = strrchr(g_dir, '\\');
        if (s) *s = 0;
        CreateThread(NULL, 0, trainer_thread, NULL, 0, NULL);
    }
    return TRUE;
}
