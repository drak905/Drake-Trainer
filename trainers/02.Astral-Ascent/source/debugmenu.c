/*
 * Astral Ascent debug menu  --  winmm.dll proxy
 *
 * Loaded by the game via its WINMM.dll import (all real exports are forwarded to the system
 * winmm, see winmm.def). Finds the game's global-variable object, then:
 *   - runs a cheat worker thread (god mode, infinite mana, locked values)
 *   - shows a native debug panel on F10 (topmost tool window) with a generic global-variable editor.
 *
 * Game object = module base + THIS_RVA (fixed for the retail exe 2.7.1, verified by signature).
 * All values are Construct "double"s at fixed offsets inside it.
 */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>
#include "globals_table.h"

#define THIS_RVA        0xA61AD08ull
/* signature of the retail object (defaults written by the registration function) */
#define SIG_OFF_A       0x1C45F0   /* 75.0  global_val_dialog_maxRecursiveRepetion */
#define SIG_OFF_B       0x1C45F8   /* 0.33  global_val_portraitResize */
/* player stats (found by live HUD experiments; see MODLOG session 4) */
#define OFF_LIFE        0x1C50D8   /* current HP (HUD) */
#define OFF_LIFEMAX     0x1C50E0   /* max HP (HUD) */
#define OFF_MANA        0x1C50F8
#define OFF_MANAMAX     0x1C5100
/* currencies (SUBAGENT-ECONOMY-02): found via registration fn FUN_144c916a0 (name copied into temp string, then
 * `lea r14,[rbx+off]`); proven live: writing here changes the HUD counters (pause screen) */
#define OFF_CUR_CRYSTALS 0x1C4018
#define OFF_CUR_KEYS     0x1C4020
#define OFF_CUR_STARS    0x1C4028
#define OFF_CUR_FEATHERS 0x1C4030
#define OFF_CUR_TICKETS  0x1C4038
#define OFF_CUR_FRAG     0x1C4040
static const unsigned CUR_OFFS[] = { OFF_CUR_CRYSTALS, OFF_CUR_KEYS, OFF_CUR_STARS, OFF_CUR_FEATHERS, OFF_CUR_TICKETS, OFF_CUR_FRAG };
static const char *CUR_NAMES[] = { "crystals", "keys", "stars", "feathers", "tickets", "destinyFrag" };
#define NCUR 6

static unsigned char *g_this;
static volatile LONG g_god, g_mana, g_curinf, g_jump, g_onehit;
static volatile LONG g_calls_jump, g_calls_dmg, g_sites_patched;

/* ---------------- aura getter hook (SUBAGENT-JUMP-05 / SUBAGENT-DAMAGE-04) ----------------
 * FUN 0x14439ba40 (RVA 0x439BA40): double GetAuraValue(void *game, double playerIdx, const std::string *tag).
 * It sums the equipped relic/aura effects that carry `tag`.  Call sites that pass the global tag constants are
 * redirected (rel32 patch -> near stub -> auraHook).  The hook calls the original, then overrides:
 *   tag 'extraJump'   -> 99   (air jump limit = extraJump + 2)
 *   tag 'damageBoost' -> +1000 (damage multiplier = 1 + damageBoost + ..., verified in the damage routine @0x141503813)
 * Tag identity = address of the game's global std::string object for that tag. */
#define RVA_AURA_GETTER      0x439BA40ull
#define RVA_TAG_EXTRAJUMP    0xC986100ull
#define RVA_TAG_DAMAGEBOOST  0xC996200ull
static const unsigned long long HOOK_SITES[] = {   /* RVAs of `call getter` instructions */
    0x337F6A1ull, 0x337FA7Full,                     /* extraJump  x2 */
    0x1503825ull, 0x3327702ull, 0x3327717ull };     /* damageBoost x3 */
typedef double (*AuraGetFn)(void *, double, const void *);
static AuraGetFn g_auraOrig;
static unsigned char *g_modbase;
static double auraHook(void *self, double p, const void *tag) {
    double v = g_auraOrig(self, p, tag);
    if (tag == (const void *)(g_modbase + RVA_TAG_EXTRAJUMP)) {
        InterlockedIncrement(&g_calls_jump);
        if (g_jump && v < 99.0) return 99.0;
    } else if (tag == (const void *)(g_modbase + RVA_TAG_DAMAGEBOOST)) {
        InterlockedIncrement(&g_calls_dmg);
        if (g_onehit) return v + 1000.0;
    }
    return v;
}
static HWND g_wnd;
static char g_logpath[MAX_PATH];

static void logf_(const char *fmt, ...) {
    FILE *f = fopen(g_logpath, "a"); if (!f) return;
    va_list ap; va_start(ap, fmt); vfprintf(f, fmt, ap); va_end(ap); fputc('\n', f); fclose(f);
}
#include <stdarg.h>

static double rdd(unsigned off) { double v; memcpy(&v, g_this + off, 8); return v; }
static void   wrd(unsigned off, double v) { memcpy(g_this + off, &v, 8); }
static void   add_currency(int i, double d) { double v = rdd(CUR_OFFS[i]) + d; if (v < 0) v = 0; wrd(CUR_OFFS[i], v); }

/* ---- locks: keep arbitrary globals pinned to a value ---- */
typedef struct { unsigned off; double val; int on; } Lock;
static Lock g_locks[32];
static CRITICAL_SECTION g_cs;

static void set_lock(unsigned off, double val, int on) {
    EnterCriticalSection(&g_cs);
    int free_i = -1;
    for (int i = 0; i < 32; i++) {
        if (g_locks[i].on && g_locks[i].off == off) { if (on) g_locks[i].val = val; else g_locks[i].on = 0; free_i = -2; break; }
        if (!g_locks[i].on && free_i == -1) free_i = i;
    }
    if (on && free_i >= 0) { g_locks[free_i].off = off; g_locks[free_i].val = val; g_locks[free_i].on = 1; }
    LeaveCriticalSection(&g_cs);
}
static int is_locked(unsigned off) {
    int r = 0; EnterCriticalSection(&g_cs);
    for (int i = 0; i < 32; i++) if (g_locks[i].on && g_locks[i].off == off) r = 1;
    LeaveCriticalSection(&g_cs); return r;
}

static DWORD WINAPI worker(LPVOID p) {
    (void)p;
    for (;;) {
        static DWORD lastlog; static LONG lj, ld;
        if (GetTickCount() - lastlog > 2000) { lastlog = GetTickCount();
            if (lj != g_calls_jump || ld != g_calls_dmg) { lj = g_calls_jump; ld = g_calls_dmg; logf_("hook calls: extraJump=%ld damageBoost=%ld (jump=%ld onehit=%ld)", lj, ld, g_jump, g_onehit); } }
        if (g_god) { double m = rdd(OFF_LIFEMAX); if (m > 0) wrd(OFF_LIFE, m); }
        if (g_mana) { double m = rdd(OFF_MANAMAX); if (m > 0) wrd(OFF_MANA, m); }
        if (g_curinf) for (int i = 0; i < NCUR; i++) wrd(CUR_OFFS[i], 99999.0);
        EnterCriticalSection(&g_cs);
        for (int i = 0; i < 32; i++) if (g_locks[i].on) wrd(g_locks[i].off, g_locks[i].val);
        LeaveCriticalSection(&g_cs);
        Sleep(4);
    }
}

/* ------------------------------ UI ------------------------------ */
enum { ID_GOD = 101, ID_MANA, ID_MAXHP, ID_SETMAXHP, ID_HEAL, ID_ENABLEDBG, ID_HPLABEL, ID_JUMP, ID_ONEHIT, ID_HOOKLBL,
       ID_CURSUM, ID_CURADD, ID_CURMAX, ID_CURINF,
       ID_FILTER = 120, ID_LIST, ID_VALUE, ID_SETVAL, ID_LOCK, ID_CURLABEL, ID_TIMER = 1 };

static int  g_sel = -1;                         /* index into GLOBALS */
static HWND h_list, h_filter, h_value, h_cur, h_lock, h_hp, h_maxhp, h_cursum, h_hook;

static void fill_list(void) {
    char f[128]; GetWindowTextA(h_filter, f, sizeof f);
    for (char *c = f; *c; c++) *c = (char)tolower((unsigned char)*c);
    SendMessageA(h_list, WM_SETREDRAW, FALSE, 0);
    SendMessageA(h_list, LB_RESETCONTENT, 0, 0);
    for (unsigned i = 0; i < NGLOBALS; i++) {
        char low[160]; strncpy(low, GLOBALS[i].name, sizeof low - 1); low[sizeof low - 1] = 0;
        for (char *c = low; *c; c++) *c = (char)tolower((unsigned char)*c);
        if (f[0] && !strstr(low, f)) continue;
        int idx = (int)SendMessageA(h_list, LB_ADDSTRING, 0, (LPARAM)GLOBALS[i].name);
        SendMessageA(h_list, LB_SETITEMDATA, idx, (LPARAM)i);
    }
    SendMessageA(h_list, WM_SETREDRAW, TRUE, 0);
}

static HWND mk(HWND par, const char *cls, const char *txt, DWORD st, int x, int y, int w, int h, int id, HFONT f) {
    HWND c = CreateWindowExA(cls[0] == 'E' ? WS_EX_CLIENTEDGE : 0, cls, txt, WS_CHILD | WS_VISIBLE | st, x, y, w, h, par,
                             (HMENU)(INT_PTR)id, GetModuleHandleA(NULL), NULL);
    SendMessageA(c, WM_SETFONT, (WPARAM)f, TRUE);
    return c;
}

static void refresh(void) {
    char b[160];
    snprintf(b, sizeof b, "HP %.0f / %.0f    Mana %.1f / %.1f", rdd(OFF_LIFE), rdd(OFF_LIFEMAX), rdd(OFF_MANA), rdd(OFF_MANAMAX));
    SetWindowTextA(h_hp, b);
    snprintf(b, sizeof b, "crystal %.0f key %.0f star %.0f feather %.0f ticket %.0f frag %.0f",
             rdd(OFF_CUR_CRYSTALS), rdd(OFF_CUR_KEYS), rdd(OFF_CUR_STARS), rdd(OFF_CUR_FEATHERS), rdd(OFF_CUR_TICKETS), rdd(OFF_CUR_FRAG));
    SetWindowTextA(h_cursum, b);
    snprintf(b, sizeof b, "hooks %ld/5  jmp %ld dmg %ld", g_sites_patched, g_calls_jump, g_calls_dmg);
    SetWindowTextA(h_hook, b);
    if (g_sel >= 0) {
        snprintf(b, sizeof b, "current: %.6g   @ +0x%X", rdd(GLOBALS[g_sel].off), GLOBALS[g_sel].off);
        SetWindowTextA(h_cur, b);
    }
}

static LRESULT CALLBACK wndproc(HWND w, UINT m, WPARAM wp, LPARAM lp) {
    static HFONT font;
    switch (m) {
    case WM_CREATE: {
        font = (HFONT)GetStockObject(DEFAULT_GUI_FONT);
        mk(w, "STATIC", "Player", 0, 10, 8, 100, 16, 0, font);
        mk(w, "BUTTON", "God mode (HP locked at max)", BS_AUTOCHECKBOX, 10, 26, 240, 20, ID_GOD, font);
        mk(w, "BUTTON", "Infinite mana", BS_AUTOCHECKBOX, 10, 48, 108, 20, ID_MANA, font);
        mk(w, "BUTTON", "Unlimited jump", BS_AUTOCHECKBOX, 120, 48, 118, 20, ID_JUMP, font);
        mk(w, "BUTTON", "One-hit kill", BS_AUTOCHECKBOX, 244, 48, 112, 20, ID_ONEHIT, font);
        h_hp = mk(w, "STATIC", "", 0, 10, 72, 340, 16, ID_HPLABEL, font);
        mk(w, "STATIC", "Max HP:", 0, 10, 98, 52, 16, 0, font);
        h_maxhp = mk(w, "EDIT", "9999", ES_AUTOHSCROLL | WS_TABSTOP, 64, 94, 70, 22, ID_MAXHP, font);
        mk(w, "BUTTON", "Set", BS_PUSHBUTTON, 140, 94, 44, 22, ID_SETMAXHP, font);
        mk(w, "BUTTON", "Heal full", BS_PUSHBUTTON, 192, 94, 70, 22, ID_HEAL, font);
        mk(w, "BUTTON", "Enable game debug flags", BS_PUSHBUTTON, 10, 124, 170, 24, ID_ENABLEDBG, font);
        h_hook = mk(w, "STATIC", "", 0, 186, 128, 170, 16, ID_HOOKLBL, font);
        h_cursum = mk(w, "STATIC", "", 0, 10, 156, 340, 16, ID_CURSUM, font);
        mk(w, "BUTTON", "+1000 all", BS_PUSHBUTTON, 10, 176, 76, 22, ID_CURADD, font);
        mk(w, "BUTTON", "Set all 99999", BS_PUSHBUTTON, 92, 176, 96, 22, ID_CURMAX, font);
        mk(w, "BUTTON", "Infinite currency (pin 99999)", BS_AUTOCHECKBOX, 194, 176, 160, 22, ID_CURINF, font);
        mk(w, "STATIC", "Global variable editor (all registered numeric globals)", 0, 10, 208, 340, 16, 0, font);
        mk(w, "STATIC", "Filter:", 0, 10, 232, 40, 16, 0, font);
        h_filter = mk(w, "EDIT", "", ES_AUTOHSCROLL | WS_TABSTOP, 52, 228, 298, 22, ID_FILTER, font);
        h_list = mk(w, "LISTBOX", "", LBS_NOTIFY | WS_VSCROLL | WS_BORDER | WS_TABSTOP, 10, 256, 340, 150, ID_LIST, font);
        h_cur = mk(w, "STATIC", "select a variable", 0, 10, 412, 340, 16, ID_CURLABEL, font);
        mk(w, "STATIC", "Value:", 0, 10, 438, 40, 16, 0, font);
        h_value = mk(w, "EDIT", "", ES_AUTOHSCROLL | WS_TABSTOP, 52, 434, 120, 22, ID_VALUE, font);
        mk(w, "BUTTON", "Set", BS_PUSHBUTTON, 180, 434, 50, 22, ID_SETVAL, font);
        h_lock = mk(w, "BUTTON", "Lock (keep value)", BS_AUTOCHECKBOX, 238, 434, 112, 22, ID_LOCK, font);
        mk(w, "STATIC", "F10 = show/hide this panel", 0, 10, 468, 340, 16, 0, font);
        fill_list();
        SetTimer(w, ID_TIMER, 200, NULL);
        return 0; }
    case WM_TIMER: refresh(); return 0;
    case WM_COMMAND: {
        int id = LOWORD(wp), nf = HIWORD(wp);
        if (id == ID_GOD) g_god = (SendMessageA((HWND)lp, BM_GETCHECK, 0, 0) == BST_CHECKED);
        else if (id == ID_MANA) g_mana = (SendMessageA((HWND)lp, BM_GETCHECK, 0, 0) == BST_CHECKED);
        else if (id == ID_JUMP) g_jump = (SendMessageA((HWND)lp, BM_GETCHECK, 0, 0) == BST_CHECKED);
        else if (id == ID_ONEHIT) g_onehit = (SendMessageA((HWND)lp, BM_GETCHECK, 0, 0) == BST_CHECKED);
        else if (id == ID_SETMAXHP) { char b[32]; GetWindowTextA(h_maxhp, b, sizeof b); double v = atof(b);
            if (v >= 1) { wrd(OFF_LIFEMAX, v); wrd(OFF_LIFE, v); } }
        else if (id == ID_HEAL) wrd(OFF_LIFE, rdd(OFF_LIFEMAX));
        else if (id == ID_CURADD) { for (int i = 0; i < NCUR; i++) add_currency(i, 1000.0); }
        else if (id == ID_CURMAX) { for (int i = 0; i < NCUR; i++) wrd(CUR_OFFS[i], 99999.0); }
        else if (id == ID_CURINF) g_curinf = (SendMessageA((HWND)lp, BM_GETCHECK, 0, 0) == BST_CHECKED);
        else if (id == ID_ENABLEDBG) {
            for (unsigned i = 0; i < NGLOBALS; i++)
                if (!strcmp(GLOBALS[i].name, "debug_enableMenu") || !strcmp(GLOBALS[i].name, "debug_debugModeEnabled__option"))
                    wrd(GLOBALS[i].off, 1.0); }
        else if (id == ID_FILTER && nf == EN_CHANGE) fill_list();
        else if (id == ID_LIST && nf == LBN_SELCHANGE) {
            int s = (int)SendMessageA(h_list, LB_GETCURSEL, 0, 0);
            if (s >= 0) { g_sel = (int)SendMessageA(h_list, LB_GETITEMDATA, s, 0);
                char b[64]; snprintf(b, sizeof b, "%.10g", rdd(GLOBALS[g_sel].off)); SetWindowTextA(h_value, b);
                SendMessageA(h_lock, BM_SETCHECK, is_locked(GLOBALS[g_sel].off) ? BST_CHECKED : BST_UNCHECKED, 0);
                refresh(); } }
        else if (id == ID_SETVAL && g_sel >= 0) { char b[64]; GetWindowTextA(h_value, b, sizeof b);
            wrd(GLOBALS[g_sel].off, atof(b));
            if (is_locked(GLOBALS[g_sel].off)) set_lock(GLOBALS[g_sel].off, atof(b), 1); }
        else if (id == ID_LOCK && g_sel >= 0) { char b[64]; GetWindowTextA(h_value, b, sizeof b);
            int on = SendMessageA(h_lock, BM_GETCHECK, 0, 0) == BST_CHECKED;
            set_lock(GLOBALS[g_sel].off, on ? atof(b) : 0, on); if (on) wrd(GLOBALS[g_sel].off, atof(b)); }
        return 0; }
    case WM_CLOSE: ShowWindow(w, SW_HIDE); return 0;      /* hide, never destroy */
    }
    return DefWindowProcA(w, m, wp, lp);
}

static DWORD WINAPI ui_thread(LPVOID p) {
    (void)p;
    WNDCLASSA wc = {0}; wc.lpfnWndProc = wndproc; wc.hInstance = GetModuleHandleA(NULL);
    wc.lpszClassName = "AADebugMenu"; wc.hbrBackground = (HBRUSH)(COLOR_BTNFACE + 1); wc.hCursor = LoadCursorA(NULL, IDC_ARROW);
    RegisterClassA(&wc);
    g_wnd = CreateWindowExA(WS_EX_TOPMOST | WS_EX_TOOLWINDOW, "AADebugMenu", "Astral Ascent - Debug Menu",
                            WS_POPUP | WS_CAPTION | WS_SYSMENU, 40, 80, 372, 530, NULL, NULL, wc.hInstance, NULL);
    logf_("ui window %p", (void *)g_wnd);
    MSG msg;
    int was = 0;
    for (;;) {
        while (PeekMessageA(&msg, NULL, 0, 0, PM_REMOVE)) {
            if (!IsDialogMessageA(g_wnd, &msg)) { TranslateMessage(&msg); DispatchMessageA(&msg); }
        }
        int down = (GetAsyncKeyState(VK_F10) & 0x8000) != 0;
        if (down && !was) {
            if (IsWindowVisible(g_wnd)) ShowWindow(g_wnd, SW_HIDE);
            else { ShowWindow(g_wnd, SW_SHOWNOACTIVATE); SetWindowPos(g_wnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE); }
        }
        was = down;
        MsgWaitForMultipleObjects(0, NULL, FALSE, 20, QS_ALLINPUT);
    }
}

/* ---------------- per-feature self-test (TRAINER_SELFTEST=1) ----------------
 * Writes trainer_selftest_report.json next to the exe; one entry per sub-agent branch so a failing
 * feature can be re-run in isolation (Gate 3 invariants + Gate 4 closed-loop deltas). */
static char g_dir[MAX_PATH];
static int finite_in(double v, double lo, double hi) { return isfinite(v) && v >= lo && v <= hi; }

static DWORD WINAPI selftest_thread(LPVOID p) {
    (void)p;
    int combat_inv = 0, combat_delta = 0, mana_inv = 0, mana_delta = 0, eco_inv = 0, eco_delta = 0;
    double hp = 0, hpmax = 0, mn = 0, mnmax = 0;
    double cur_before[NCUR] = {0}, cur_after[NCUR] = {0};
    int waited = 0;
    /* wait for a live player (HP max > 0), up to 2 min */
    while (waited < 240 && !(rdd(OFF_LIFEMAX) > 0)) { Sleep(500); waited++; }
    Sleep(1500);
    hp = rdd(OFF_LIFE); hpmax = rdd(OFF_LIFEMAX); mn = rdd(OFF_MANA); mnmax = rdd(OFF_MANAMAX);
    combat_inv = finite_in(hpmax, 1, 1e7) && finite_in(hp, 0, hpmax * 2);
    mana_inv   = finite_in(mnmax, 0.1, 1e6) && finite_in(mn, 0, mnmax * 2);
    /* delta: damage the player, god mode must snap HP back to max */
    if (combat_inv) {
        LONG old = g_god; double orig = hp;
        g_god = 1; wrd(OFF_LIFE, hpmax > 2 ? hpmax / 2 : 1); Sleep(150);
        combat_delta = (rdd(OFF_LIFE) == hpmax);
        g_god = old; if (!old) wrd(OFF_LIFE, orig);
    }
    if (mana_inv) {
        LONG old = g_mana; double orig = mn;
        g_mana = 1; wrd(OFF_MANA, 0.0); Sleep(150);
        mana_delta = (rdd(OFF_MANA) == mnmax);
        g_mana = old; if (!old) wrd(OFF_MANA, orig);
    }
    /* economy: +10 then read back (must persist, i.e. not a transient shadow copy), then restore */
    eco_inv = 1; eco_delta = 1;
    for (int i = 0; i < NCUR; i++) {
        cur_before[i] = rdd(CUR_OFFS[i]);
        if (!finite_in(cur_before[i], 0, 1e9)) eco_inv = 0;
    }
    if (eco_inv) {
        for (int i = 0; i < NCUR; i++) add_currency(i, 10.0);
        Sleep(400);   /* game gets several frames to overwrite a shadow copy */
        for (int i = 0; i < NCUR; i++) { cur_after[i] = rdd(CUR_OFFS[i]); if (cur_after[i] != cur_before[i] + 10.0) eco_delta = 0; }
        for (int i = 0; i < NCUR; i++) wrd(CUR_OFFS[i], cur_before[i]);
    } else eco_delta = 0;

    int all = combat_inv && combat_delta && mana_inv && mana_delta && eco_inv && eco_delta;
    char path[MAX_PATH]; snprintf(path, sizeof path, "%s\\trainer_selftest_report.json", g_dir);
    FILE *f = fopen(path, "w");
    if (f) {
        fprintf(f, "{\n  \"overall_status\": \"%s\",\n  \"player_wait_halfsec_ticks\": %d,\n  \"feature_results\": [\n", all ? "PASS_READY_FOR_HUMAN" : "PARTIAL_FAIL_NEEDS_ISOLATED_HEAL", waited);
        fprintf(f, "    {\"subagent_branch_id\": \"SUBAGENT-COMBAT-01\", \"hook_status\": \"memory_object_verified\", \"invariant_check\": \"%s\", \"delta_test_result\": \"%s\", \"observed_hp\": %.2f, \"observed_max_hp\": %.2f},\n",
                combat_inv ? "PASS" : "FAIL_INVALID_INVARIANT", combat_delta ? "PASS" : "FAIL", hp, hpmax);
        fprintf(f, "    {\"subagent_branch_id\": \"SUBAGENT-STAMINA-03\", \"hook_status\": \"memory_object_verified\", \"invariant_check\": \"%s\", \"delta_test_result\": \"%s\", \"observed_mana\": %.2f, \"observed_max_mana\": %.2f},\n",
                mana_inv ? "PASS" : "FAIL_INVALID_INVARIANT", mana_delta ? "PASS" : "FAIL", mn, mnmax);
        fprintf(f, "    {\"subagent_branch_id\": \"SUBAGENT-ECONOMY-02\", \"hook_status\": \"memory_object_verified\", \"invariant_check\": \"%s\", \"delta_test_result\": \"%s\", \"currencies\": {",
                eco_inv ? "PASS" : "FAIL_INVALID_INVARIANT", eco_delta ? "PASS" : "FAIL");
        for (int i = 0; i < NCUR; i++)
            fprintf(f, "%s\"%s\": {\"before\": %.0f, \"after_plus10\": %.0f}", i ? ", " : "", CUR_NAMES[i], cur_before[i], cur_after[i]);
        fprintf(f, "}},\n");
        fprintf(f, "    {\"subagent_branch_id\": \"SUBAGENT-JUMP-05\", \"hook_status\": \"%ld/5 call sites patched\", \"invariant_check\": \"%s\", \"delta_test_result\": \"NEEDS_GAMEPLAY (see aa_debugmenu.log hook counters)\", \"hook_calls_extraJump\": %ld},\n",
                g_sites_patched, g_sites_patched == 5 ? "PASS" : "FAIL", g_calls_jump);
        fprintf(f, "    {\"subagent_branch_id\": \"SUBAGENT-DAMAGE-04\", \"hook_status\": \"%ld/5 call sites patched\", \"invariant_check\": \"%s\", \"delta_test_result\": \"NEEDS_GAMEPLAY (see aa_debugmenu.log hook counters)\", \"hook_calls_damageBoost\": %ld}\n  ]\n}\n",
                g_sites_patched, g_sites_patched == 5 ? "PASS" : "FAIL", g_calls_dmg);
        fclose(f);
    }
    logf_("selftest done: overall=%s", all ? "PASS" : "FAIL");
    return 0;
}

/* ---------------- hook installation (runtime rel32 call-site patch, no exe modification on disk) ---------------- */
static void install_hooks(void) {
    g_modbase = (unsigned char *)GetModuleHandleA(NULL);
    g_auraOrig = (AuraGetFn)(void *)(g_modbase + RVA_AURA_GETTER);
    IMAGE_DOS_HEADER *dh = (IMAGE_DOS_HEADER *)g_modbase;
    IMAGE_NT_HEADERS *nt = (IMAGE_NT_HEADERS *)(g_modbase + dh->e_lfanew);
    unsigned char *img_end = g_modbase + nt->OptionalHeader.SizeOfImage;
    unsigned char *stub = NULL;
    for (unsigned char *a = img_end; a < g_modbase + 0x70000000ull && !stub; a += 0x10000)
        stub = (unsigned char *)VirtualAlloc(a, 0x1000, MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE);
    if (!stub) { logf_("hooks: no executable memory near image, jump/damage hooks disabled"); return; }
    stub[0] = 0x48; stub[1] = 0xB8;                 /* mov rax, imm64 */
    unsigned long long target = (unsigned long long)(void *)auraHook;
    memcpy(stub + 2, &target, 8);
    stub[10] = 0xFF; stub[11] = 0xE0;               /* jmp rax */
    for (unsigned i = 0; i < sizeof HOOK_SITES / sizeof HOOK_SITES[0]; i++) {
        unsigned char *p = g_modbase + HOOK_SITES[i];
        int rel; memcpy(&rel, p + 1, 4);
        if (p[0] != 0xE8) { logf_("hooks: site %llx is not a call (%02x) - skipped", HOOK_SITES[i], p[0]); continue; }
        if (p + 5 + rel == (unsigned char *)(void *)(stub)) { g_sites_patched++; continue; }   /* already ours */
        if (p + 5 + rel != g_modbase + RVA_AURA_GETTER) { logf_("hooks: site %llx calls elsewhere - skipped", HOOK_SITES[i]); continue; }
        if ((((uintptr_t)(p + 1)) & 63) > 60) { logf_("hooks: site %llx straddles a cache line - skipped", HOOK_SITES[i]); continue; }
        long long nrel = (long long)(stub - (p + 5));
        if (nrel > 0x7FFFFFFFll || nrel < -0x7FFFFFFFll) { logf_("hooks: stub out of rel32 range"); continue; }
        DWORD old;
        if (!VirtualProtect(p + 1, 4, PAGE_EXECUTE_READWRITE, &old)) { logf_("hooks: VirtualProtect failed"); continue; }
        LONG v = (LONG)nrel;
        *(volatile LONG *)(p + 1) = v;              /* single 4-byte store inside one cache line */
        VirtualProtect(p + 1, 4, old, &old);
        FlushInstructionCache(GetCurrentProcess(), p, 8);
        g_sites_patched++;
    }
    logf_("hooks: %ld/%d call sites patched, stub at %p", g_sites_patched, (int)(sizeof HOOK_SITES / sizeof HOOK_SITES[0]), (void *)stub);
}

static DWORD WINAPI init_thread(LPVOID p) {
    (void)p;
    char dll[MAX_PATH]; HMODULE self; GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT, (LPCSTR)init_thread, &self);
    GetModuleFileNameA(self, dll, MAX_PATH); char *s = strrchr(dll, '\\'); if (s) *s = 0;
    strncpy(g_dir, dll, sizeof g_dir - 1);
    snprintf(g_logpath, sizeof g_logpath, "%s\\aa_debugmenu.log", dll);
    unsigned char *base = (unsigned char *)GetModuleHandleA(NULL);
    unsigned char *t = base + THIS_RVA;
    logf_("--- start. module base %p, expected game object %p", (void *)base, (void *)t);
    /* wait until the registration code has initialised the object, verify the signature */
    for (int i = 0; i < 600; i++) {                 /* up to ~5 min */
        double a, b;
        if (!IsBadReadPtr(t + SIG_OFF_B, 8)) {
            memcpy(&a, t + SIG_OFF_A, 8); memcpy(&b, t + SIG_OFF_B, 8);
            if (a == 75.0 && b > 0.329 && b < 0.331) { g_this = t; break; }
        }
        Sleep(500);
    }
    if (!g_this) { logf_("signature mismatch - wrong exe version? menu disabled"); return 0; }
    logf_("game object verified");
    install_hooks();
    InitializeCriticalSection(&g_cs);
    CreateThread(NULL, 0, worker, NULL, 0, NULL);
    CreateThread(NULL, 0, ui_thread, NULL, 0, NULL);
    { char e[8]; char flag[MAX_PATH]; snprintf(flag, sizeof flag, "%s\\trainer_selftest.flag", g_dir);
      int on = (GetEnvironmentVariableA("TRAINER_SELFTEST", e, sizeof e) && e[0] == '1') || GetFileAttributesA(flag) != INVALID_FILE_ATTRIBUTES;
      if (on) CreateThread(NULL, 0, selftest_thread, NULL, 0, NULL); }
    return 0;
}

BOOL WINAPI DllMain(HINSTANCE h, DWORD reason, LPVOID r) {
    (void)r;
    if (reason == DLL_PROCESS_ATTACH) { DisableThreadLibraryCalls(h); CreateThread(NULL, 0, init_thread, NULL, 0, NULL); }
    return TRUE;
}
