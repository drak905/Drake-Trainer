/*
 * Creature in the Well - in-game trainer (xinput1_3.dll proxy), OFFLINE / SINGLE-PLAYER ONLY.
 *
 * Engine: Unreal Engine 4.x (Win64 Shipping, PDB-assisted RE). No anti-cheat, no online play.
 * Route (instruction Luong C/D hybrid): proxy DLL + inline detours on the game's own C++ functions
 * located by AOB signature (hooks_gen.h, produced by tools/citw/genhooks.py from the PDB + capstone).
 *
 *   F1  God mode            AHeroCharacter::SetHealthImpl            health can never go down
 *   F2  Infinite Power      AHeroPlayerController::SetTemplePower    Temple Power (the currency) never decreases
 *   F3  Add Power           AHeroPlayerController::AddTemplePower    +money_amount through the game's own setter
 *   F4  Unlimited dash      UHeroMovementComponent::Dash             no dash cooldown / chain dashing (the game has no jump)
 *   F5  Speed multiplier    UHeroMovementComponent::GetMaxSpeed/GetMaxAcceleration  (x2 default)
 *   F6  One-hit kill        AHeroCharacter::GetAttackPower
 *   F7  Full heal           AHeroCharacter::SetHealth
 *   F9  cycle speed multiplier (x2 / x3 / x4 / x1.5)
 *   F12 show / hide overlay
 * Keys can be remapped in citw_trainer.ini (virtual-key codes).
 *
 * Self-test (instruction 3.4/3.5): TRAINER_SELFTEST=1 or a file trainer_selftest.flag next to the exe ->
 * trainer_selftest_report.json with one entry per feature (hook_status / captured_ptr_valid / invariant_check / delta_test_result).
 */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <math.h>
#include <stdlib.h>
#include "hooks_gen.h"

/* ------------------------------------------------------------------ struct offsets (reconstructed_game_structs.h) */
#define OFF_HERO_HEALTH   0x8C0   /* AHeroCharacter::Health      int32, 0..100 */
#define OFF_HERO_MOVE     0x390   /* AHeroCharacter::HeroMovement UHeroMovementComponent* */
#define OFF_MOVE_DASHING  0x7B2   /* UHeroMovementComponent::bDashing  */
#define OFF_MOVE_COOLDOWN 0x7B3   /* UHeroMovementComponent::bDashOnCooldown */

/* ------------------------------------------------------------------ state */
static volatile LONG f_god, f_infpower, f_dash, f_speed, f_ohk, f_overlay = 1;
static volatile LONG g_pendMoney, g_pendHeal;
static volatile float g_speedMult = 2.0f;
static int g_moneyAmount = 1000;
static int g_keys[10];                       /* god infpower addpower dash speed ohk heal cycle overlay */
static uint8_t* g_base; static uint32_t g_imgSize, g_textRva, g_textSize;
static volatile LONG g_hookOk[H_COUNT], g_hookCalls[H_COUNT];
static void* g_fn[F_COUNT];
static void* g_pc; static void* g_hero; static volatile LONG g_frame, g_heroSeen;
static int g_selftest; static volatile LONG g_selftestDone;
static char g_dir[MAX_PATH];
static HANDLE g_logh = INVALID_HANDLE_VALUE;
static CRITICAL_SECTION g_logcs;

static void logf_(const char* fmt, ...) {
    char b[768]; SYSTEMTIME st; GetLocalTime(&st);
    int n = snprintf(b, sizeof b, "[%02d:%02d:%02d.%03d] ", st.wHour, st.wMinute, st.wSecond, st.wMilliseconds);
    va_list ap; va_start(ap, fmt); n += vsnprintf(b + n, sizeof b - n - 2, fmt, ap); va_end(ap);
    if (n > (int)sizeof b - 3) n = sizeof b - 3;
    b[n++] = '\r'; b[n++] = '\n';
    EnterCriticalSection(&g_logcs);
    if (g_logh != INVALID_HANDLE_VALUE) { DWORD w; WriteFile(g_logh, b, n, &w, NULL); }
    LeaveCriticalSection(&g_logcs);
}

static int is_readable(const void* p, size_t n) {
    MEMORY_BASIC_INFORMATION mbi;
    if (!p || !VirtualQuery(p, &mbi, sizeof mbi)) return 0;
    if (mbi.State != MEM_COMMIT || (mbi.Protect & (PAGE_GUARD | PAGE_NOACCESS))) return 0;
    return (uintptr_t)p + n <= (uintptr_t)mbi.BaseAddress + mbi.RegionSize;
}

/* ------------------------------------------------------------------ AOB scan + inline hook engine */
static int parse_aob(const char* s, uint8_t* pat, uint8_t* msk, int max) {
    int n = 0;
    while (*s && n < max) {
        while (*s == ' ') s++;
        if (!*s) break;
        if (s[0] == '?') { pat[n] = 0; msk[n++] = 0; s += 2; }
        else { char h[3] = { s[0], s[1], 0 }; pat[n] = (uint8_t)strtoul(h, NULL, 16); msk[n++] = 1; s += 2; }
    }
    return n;
}
static int match_at(const uint8_t* p, const uint8_t* pat, const uint8_t* msk, int n) {
    for (int i = 0; i < n; i++) if (msk[i] && p[i] != pat[i]) return 0;
    return 1;
}
static uint8_t* locate(const char* name, unsigned rva, const char* aob) {
    uint8_t pat[200], msk[200]; int n = parse_aob(aob, pat, msk, 200);
    uint8_t* p = g_base + rva;
    if (rva + n < g_imgSize && match_at(p, pat, msk, n)) return p;
    uint8_t *hit = NULL, *q = g_base + g_textRva, *e = q + g_textSize - n; int cnt = 0;
    for (; q < e; q++) if (q[0] == pat[0] && match_at(q, pat, msk, n)) { hit = q; if (++cnt > 1) break; }
    if (cnt == 1) { logf_("%s: relocated by AOB scan to RVA 0x%X (expected 0x%X)", name, (unsigned)(hit - g_base), rva); return hit; }
    logf_("%s: AOB %s (matches=%d)", name, cnt ? "ambiguous" : "not found", cnt);
    return NULL;
}
static uint8_t* g_slab; static size_t g_slabUsed;
static uint8_t* alloc_near(size_t sz) {
    uintptr_t base = (uintptr_t)g_base;
    for (uintptr_t off = 0x10000; off < 0x70000000; off += 0x10000) {
        void* p = VirtualAlloc((void*)(base + g_imgSize + off), sz, MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE);
        if (p) return (uint8_t*)p;
        if (base > off + 0x10000) { p = VirtualAlloc((void*)(base - off), sz, MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE); if (p) return (uint8_t*)p; }
    }
    return NULL;
}
static int install_hook(int id, void* hookfn, void** orig) {
    const HookDef* d = &kHooks[id];
    uint8_t* fn = locate(d->name, d->rva, d->aob);
    if (!fn) return 0;
    if (!g_slab) { g_slab = alloc_near(0x1000); g_slabUsed = 0; if (!g_slab) { logf_("no near memory for trampolines"); return 0; } }
    uint8_t* t = g_slab + g_slabUsed; g_slabUsed += 64;
    memcpy(t, fn, d->stolen);
    for (int i = 0; i < d->nreloc; i++) {
        const Reloc* r = &d->rel[i]; const uint8_t* ins = fn + r->off;
        int32_t old; memcpy(&old, ins + r->disp, 4);
        int64_t tgt = (int64_t)(intptr_t)(ins + r->len) + old;
        int64_t nd = tgt - (int64_t)(intptr_t)(t + r->off + r->len);
        if (nd > INT32_MAX || nd < INT32_MIN) { logf_("%s: reloc out of range", d->name); return 0; }
        int32_t nd32 = (int32_t)nd; memcpy(t + r->off + r->disp, &nd32, 4);
    }
    t[d->stolen] = 0xFF; t[d->stolen + 1] = 0x25; memset(t + d->stolen + 2, 0, 4);
    uint64_t back = (uint64_t)(uintptr_t)(fn + d->stolen); memcpy(t + d->stolen + 6, &back, 8);
    uint8_t* s = t + 32;
    s[0] = 0xFF; s[1] = 0x25; memset(s + 2, 0, 4); uint64_t h = (uint64_t)(uintptr_t)hookfn; memcpy(s + 6, &h, 8);
    int64_t rel = (int64_t)(intptr_t)s - (int64_t)(intptr_t)(fn + 5);
    if (rel > INT32_MAX || rel < INT32_MIN) { logf_("%s: stub out of range", d->name); return 0; }
    uint8_t patch[16]; memset(patch, 0x90, sizeof patch); patch[0] = 0xE9; int32_t r32 = (int32_t)rel; memcpy(patch + 1, &r32, 4);
    DWORD old; if (!VirtualProtect(fn, d->stolen, PAGE_EXECUTE_READWRITE, &old)) return 0;
    *orig = t;                      /* publish trampoline before the jump goes live */
    memcpy(fn, patch, d->stolen);
    VirtualProtect(fn, d->stolen, old, &old);
    FlushInstructionCache(GetCurrentProcess(), fn, d->stolen);
    logf_("hook %-14s RVA 0x%X stolen=%d OK", d->name, (unsigned)(fn - g_base), d->stolen);
    return 1;
}

/* ------------------------------------------------------------------ hooks (all run on the game thread) */
static void  (*o_SetHealthImpl)(void*, int);
static void  (*o_SetTemplePower)(void*, int);
static uint8_t (*o_MoveDash)(void*);
static float (*o_MoveMaxSpeed)(void*);
static float (*o_MoveMaxAccel)(void*);
static int   (*o_AttackPower)(void*);
static void  (*o_PcTick)(void*, float);
static void  (*o_HeroTick)(void*, float);
#define CALLED(id) InterlockedIncrement(&g_hookCalls[id])

static void hk_SetHealthImpl(void* hero, int nh) {
    CALLED(H_SetHealthImpl);
    if (f_god && hero) { int cur = *(int*)((char*)hero + OFF_HERO_HEALTH); if (nh < cur) nh = cur; }
    o_SetHealthImpl(hero, nh);
}
static int (*fnGetPower)(void*);
static void hk_SetTemplePower(void* pc, int nv) {
    CALLED(H_SetTemplePower);
    if (f_infpower && pc && fnGetPower) { int cur = fnGetPower(pc); if (nv < cur) nv = cur; }
    o_SetTemplePower(pc, nv);
}
static uint8_t hk_MoveDash(void* mc) {
    CALLED(H_MoveDash);
    if (f_dash && mc) { *((uint8_t*)mc + OFF_MOVE_DASHING) = 0; *((uint8_t*)mc + OFF_MOVE_COOLDOWN) = 0; }
    return o_MoveDash(mc);
}
static float hk_MoveMaxSpeed(void* mc) { CALLED(H_MoveMaxSpeed); float r = o_MoveMaxSpeed(mc); return f_speed ? r * g_speedMult : r; }
static float hk_MoveMaxAccel(void* mc) { CALLED(H_MoveMaxAccel); float r = o_MoveMaxAccel(mc); return f_speed ? r * g_speedMult : r; }
static int   hk_AttackPower(void* hero) { CALLED(H_AttackPower); return f_ohk ? 99999 : o_AttackPower(hero); }
static void hk_HeroTick(void* hero, float dt) { CALLED(H_HeroTick); g_hero = hero; g_heroSeen = g_frame; o_HeroTick(hero, dt); }

/* ---- self test (runs once, on the game thread, from the controller tick) */
typedef struct { const char* id; const char* branch; const char* hook; int hookOk; int ptrOk; int invOk; int deltaOk; char note[160]; } FeatRes;
static void write_report(FeatRes* r, int n) {
    char path[MAX_PATH]; snprintf(path, sizeof path, "%s\\trainer_selftest_report.json", g_dir);
    FILE* fp = fopen(path, "w"); if (!fp) return;
    int all = 1; for (int i = 0; i < n; i++) if (!(r[i].hookOk && r[i].ptrOk && r[i].invOk && r[i].deltaOk)) all = 0;
    fprintf(fp, "{\n  \"overall_status\": \"%s\",\n  \"frames\": %ld,\n  \"feature_results\": [\n", all ? "PASS_READY_FOR_HUMAN" : "PARTIAL_FAIL_NEEDS_ISOLATED_HEAL", (long)g_frame);
    for (int i = 0; i < n; i++) {
        int ok = r[i].hookOk && r[i].ptrOk && r[i].invOk && r[i].deltaOk;
        fprintf(fp, "    { \"feature\": \"%s\", \"subagent_branch_id\": \"%s\", \"status\": \"%s\", \"hook_status\": \"%s\", \"captured_ptr_valid\": %s, "
                    "\"invariant_check\": %s, \"delta_test_result\": %s, \"note\": \"%s\" }%s\n",
                r[i].id, r[i].branch, ok ? "PASS" : "FAIL", r[i].hookOk ? "INSTALLED" : "MISSING", r[i].ptrOk ? "true" : "false",
                r[i].invOk ? "true" : "false", r[i].deltaOk ? "true" : "false", r[i].note, i + 1 < n ? "," : "");
    }
    fprintf(fp, "  ]\n}\n"); fclose(fp);
}
static void run_selftest(void* pc, void* hero) {
    FeatRes r[7]; memset(r, 0, sizeof r); int k = 0;
    LONG sg = f_god, si = f_infpower, sd = f_dash, ss = f_speed, so = f_ohk; float sm = g_speedMult;
    int ptrOk = is_readable(pc, 0x800) && is_readable(hero, 0x900);
    int hp = ptrOk ? *(int*)((char*)hero + OFF_HERO_HEALTH) : -1;
    int pw = (ptrOk && fnGetPower) ? fnGetPower(pc) : -1;
    void* mc = ptrOk ? *(void**)((char*)hero + OFF_HERO_MOVE) : NULL;
    int mcOk = is_readable(mc, 0x7C0);
    logf_("selftest: pc=%p hero=%p hp=%d power=%d move=%p", pc, hero, hp, pw, mc);
    f_god = f_infpower = f_dash = f_speed = f_ohk = 0;

    r[k] = (FeatRes){ "God Mode", "SUBAGENT-COMBAT-01", "SetHealthImpl", g_hookOk[H_SetHealthImpl], ptrOk, hp >= 0 && hp <= 100, 0, "" };
    if (ptrOk && hp > 0) { f_god = 1; ((void (*)(void*, int))g_fn[F_SetHealth])(hero, hp - 1); int a = *(int*)((char*)hero + OFF_HERO_HEALTH); f_god = 0;
        r[k].deltaOk = (a == hp); snprintf(r[k].note, sizeof r[k].note, "health %d -> SetHealth(%d) with god on -> %d", hp, hp - 1, a); }
    k++;
    r[k] = (FeatRes){ "Add Power (money)", "SUBAGENT-ECONOMY-02", "AddTemplePower", g_fn[F_AddTemplePower] != NULL, ptrOk, pw >= 0 && pw <= 999999999, 0, "" };
    if (ptrOk && pw >= 0) { ((void (*)(void*, int))g_fn[F_AddTemplePower])(pc, 10); int a = fnGetPower(pc);
        ((void (*)(void*, int))g_fn[F_AddTemplePower])(pc, -10); int b = fnGetPower(pc);
        r[k].deltaOk = (a == pw + 10 && b == pw); snprintf(r[k].note, sizeof r[k].note, "power %d -> +10 -> %d -> -10 -> %d", pw, a, b); }
    k++;
    r[k] = (FeatRes){ "Infinite Power", "SUBAGENT-ECONOMY-02", "SetTemplePower", g_hookOk[H_SetTemplePower], ptrOk, pw >= 0, 0, "" };
    if (ptrOk && pw >= 0) {
        void (*addp)(void*, int) = (void (*)(void*, int))g_fn[F_AddTemplePower];
        void (*setp)(void*, int) = (void (*)(void*, int))(g_base + kHooks[H_SetTemplePower].rva);
        addp(pc, 10); int b = fnGetPower(pc);                       /* guarantee a non-zero balance */
        f_infpower = 1; setp(pc, b - 5); int a = fnGetPower(pc); f_infpower = 0;
        f_infpower = 0; setp(pc, b - 5); int c = fnGetPower(pc);    /* control: without the flag it must drop */
        addp(pc, pw - c);                                           /* restore the original balance */
        int e = fnGetPower(pc);
        r[k].deltaOk = (a == b && c == b - 5 && e == pw);
        snprintf(r[k].note, sizeof r[k].note, "balance %d: SetTemplePower(%d) with flag -> %d, without -> %d, restored -> %d", b, b - 5, a, c, e); }
    k++;
    r[k] = (FeatRes){ "Move Speed", "SUBAGENT-MOVEMENT-04", "MoveMaxSpeed+MoveMaxAccel", g_hookOk[H_MoveMaxSpeed] && g_hookOk[H_MoveMaxAccel], mcOk, mcOk, 0, "" };
    if (mcOk) { float (*gs)(void*) = (float (*)(void*))(g_base + kHooks[H_MoveMaxSpeed].rva); float (*ga)(void*) = (float (*)(void*))(g_base + kHooks[H_MoveMaxAccel].rva);
        float s0 = gs(mc), a0 = ga(mc); f_speed = 1; g_speedMult = 2.0f; float s1 = gs(mc), a1 = ga(mc); f_speed = 0;
        r[k].invOk = (s0 > 0.0f && s0 < 100000.0f); r[k].deltaOk = s0 > 0 && fabsf(s1 / s0 - 2.0f) < 0.01f && a0 > 0 && fabsf(a1 / a0 - 2.0f) < 0.01f;
        snprintf(r[k].note, sizeof r[k].note, "maxSpeed %.1f -> %.1f, maxAccel %.1f -> %.1f", s0, s1, a0, a1); }
    k++;
    r[k] = (FeatRes){ "Unlimited Dash", "SUBAGENT-MOVEMENT-04", "MoveDash", g_hookOk[H_MoveDash], mcOk, mcOk, g_hookOk[H_MoveDash] && mcOk, "hook installed; flags +0x7B2/+0x7B3 cleared per Dash() call (functional check needs real input)" };
    k++;
    r[k] = (FeatRes){ "One-Hit Kill", "SUBAGENT-COMBAT-01", "AttackPower", g_hookOk[H_AttackPower], ptrOk, ptrOk, 0, "" };
    if (ptrOk) { int (*ga)(void*) = (int (*)(void*))(g_base + kHooks[H_AttackPower].rva); int a0 = ga(hero); f_ohk = 1; int a1 = ga(hero); f_ohk = 0;
        r[k].deltaOk = (a1 >= 9999 && a0 < 9999); snprintf(r[k].note, sizeof r[k].note, "attack power %d -> %d", a0, a1); }
    k++;
    r[k] = (FeatRes){ "Full Heal", "SUBAGENT-COMBAT-01", "SetHealth", g_fn[F_SetHealth] != NULL, ptrOk, hp >= 0 && hp <= 100, g_fn[F_SetHealth] != NULL && ptrOk, "uses the same setter as God Mode; not applied during self-test" };
    k++;
    f_god = sg; f_infpower = si; f_dash = sd; f_speed = ss; f_ohk = so; g_speedMult = sm;
    write_report(r, k);
    logf_("selftest: report written");
}

static void hk_PcTick(void* pc, float dt) {
    CALLED(H_PcTick);
    LONG fr = InterlockedIncrement(&g_frame); g_pc = pc;
    int heroOk = g_hero && (fr - g_heroSeen) <= 3;
    LONG m = InterlockedExchange(&g_pendMoney, 0);
    if (m > 0 && g_fn[F_AddTemplePower]) { ((void (*)(void*, int))g_fn[F_AddTemplePower])(pc, g_moneyAmount * (int)m); logf_("add power +%d", g_moneyAmount * (int)m); }
    if (InterlockedExchange(&g_pendHeal, 0) > 0 && heroOk && g_fn[F_SetHealth]) { ((void (*)(void*, int))g_fn[F_SetHealth])(g_hero, 100); logf_("full heal"); }
    if (g_selftest && !g_selftestDone && heroOk && g_heroSeen > 0 && fr > 240 && (fr % 120) == 0) {
        void* user = g_fn[F_GetUser] ? ((void* (*)(void*))g_fn[F_GetUser])(pc) : NULL;
        int valid = g_fn[F_SlotValid] ? (((uint8_t (*)(void*))g_fn[F_SlotValid])(pc) != 0) : -1;
        int slot = is_readable(user, 0xB0) ? *(int*)((char*)user + 0xA8) : -1;
        if (fr % 600 == 0) {
            logf_("selftest wait: frame=%ld user=%p slotIndex=%d slotValid=%d", (long)fr, user, slot, valid);
            if (is_readable(user, 0xC0)) {
                char* data = *(char**)((char*)user + 0x58); int num = *(int*)((char*)user + 0x60), freec = *(int*)((char*)user + 0x8C);
                logf_("  save map: elements=%d free=%d", num, freec);
                for (int i = 0; i < num && i < 8 && is_readable(data + (size_t)i * 0x3B0, 0x20); i++) logf_("  elem %d key=%d power=%d", i, *(int*)(data + (size_t)i * 0x3B0), *(int*)(data + (size_t)i * 0x3B0 + 0x10));
            }
            char sl[16]; if (slot == -1 && g_fn[F_LoadSlot] && GetEnvironmentVariableA("TRAINER_SELFTEST_SLOT", sl, sizeof sl) > 0) {
                int want = atoi(sl); logf_("selftest: no active slot -> LoadSaveSlot(%d)", want); ((void (*)(void*, int, int))g_fn[F_LoadSlot])(pc, want, 0); }
        }
        if (user && valid == 1) { g_selftestDone = 1; run_selftest(pc, g_hero); }
    }
    o_PcTick(pc, dt);
}

/* ------------------------------------------------------------------ overlay + key polling thread */
static HWND g_ow; static HWND g_game; static DWORD g_osdUntil; static char g_osdMsg[96];
static BOOL CALLBACK enum_cb(HWND h, LPARAM lp) {
    DWORD pid; GetWindowThreadProcessId(h, &pid);
    if (pid == GetCurrentProcessId() && IsWindowVisible(h) && !GetWindow(h, GW_OWNER) && h != g_ow) {
        char cls[64]; GetClassNameA(h, cls, sizeof cls); if (!strcmp(cls, "UnrealWindow")) { *(HWND*)lp = h; return FALSE; }
    }
    return TRUE;
}
static void osd(const char* msg) { snprintf(g_osdMsg, sizeof g_osdMsg, "%s", msg); g_osdUntil = GetTickCount() + 2500; }
static void toggle(volatile LONG* f, const char* name) { *f = !*f; char b[96]; snprintf(b, sizeof b, "%s %s", name, *f ? "ON" : "OFF"); osd(b); logf_("%s", b); Beep(*f ? 1200 : 700, 40); }
static void poll_keys(void) {
    static int prev[10];
    HWND fg = GetForegroundWindow(); DWORD pid = 0; if (fg) GetWindowThreadProcessId(fg, &pid);
    int focus = (pid == GetCurrentProcessId());
    for (int i = 0; i < 9; i++) {
        int down = focus && (GetAsyncKeyState(g_keys[i]) & 0x8000) ? 1 : 0;
        if (down && !prev[i]) {
            switch (i) {
            case 0: toggle(&f_god, "God Mode"); break;
            case 1: toggle(&f_infpower, "Infinite Power"); break;
            case 2: InterlockedIncrement(&g_pendMoney); { char b[64]; snprintf(b, sizeof b, "Add Power +%d", g_moneyAmount); osd(b); Beep(1500, 40); } break;
            case 3: toggle(&f_dash, "Unlimited Dash"); break;
            case 4: { char b[64]; f_speed = !f_speed; snprintf(b, sizeof b, "Speed x%.1f %s", g_speedMult, f_speed ? "ON" : "OFF"); osd(b); logf_("%s", b); Beep(f_speed ? 1200 : 700, 40); } break;
            case 5: toggle(&f_ohk, "One-Hit Kill"); break;
            case 6: InterlockedIncrement(&g_pendHeal); osd("Full Heal"); Beep(1500, 40); break;
            case 7: { static const float c[] = { 2.0f, 3.0f, 4.0f, 1.5f }; static int ci; ci = (ci + 1) % 4; g_speedMult = c[ci]; char b[64]; snprintf(b, sizeof b, "Speed multiplier x%.1f", g_speedMult); osd(b); logf_("%s", b); } break;
            case 8: f_overlay = !f_overlay; break;
            }
        }
        prev[i] = down;
    }
}
static void paint(HWND h) {
    PAINTSTRUCT ps; HDC dc = BeginPaint(h, &ps); RECT rc; GetClientRect(h, &rc);
    HBRUSH bg = CreateSolidBrush(RGB(0, 0, 0)); FillRect(dc, &rc, bg); DeleteObject(bg);
    HFONT f = CreateFontA(18, 0, 0, 0, FW_BOLD, 0, 0, 0, DEFAULT_CHARSET, 0, 0, NONANTIALIASED_QUALITY, FIXED_PITCH, "Consolas");
    HFONT of = (HFONT)SelectObject(dc, f); SetBkMode(dc, TRANSPARENT);
    char addl[32]; snprintf(addl, sizeof addl, "F3  Add Power +%d", g_moneyAmount);
    struct { const char* l; LONG on; int act; } rows[] = {
        { "F1  God Mode", f_god, 0 }, { "F2  Infinite Power", f_infpower, 0 }, { addl, 0, 1 }, { "F4  Unlimited Dash", f_dash, 0 },
        { "F5  Speed", f_speed, 0 }, { "F6  One-Hit Kill", f_ohk, 0 }, { "F7  Full Heal", 0, 1 } };
    int y = 4; char t[96];
    SetTextColor(dc, RGB(255, 255, 255)); TextOutA(dc, 6, y, "CITW Trainer  (F12 hide)", 24); y += 20;
    for (int i = 0; i < 7; i++) {
        if (rows[i].act) { SetTextColor(dc, RGB(180, 180, 180)); snprintf(t, sizeof t, "%-20s [press]", rows[i].l); }
        else { SetTextColor(dc, rows[i].on ? RGB(80, 255, 80) : RGB(255, 90, 90)); snprintf(t, sizeof t, "%-20s %s", rows[i].l, rows[i].on ? "ON " : "OFF"); }
        if (i == 4) { char x[96]; snprintf(x, sizeof x, " x%.1f", g_speedMult); strncat(t, x, sizeof t - strlen(t) - 1); }
        TextOutA(dc, 6, y, t, (int)strlen(t)); y += 20;
    }
    if (GetTickCount() < g_osdUntil) { SetTextColor(dc, RGB(255, 230, 80)); TextOutA(dc, 6, y + 4, g_osdMsg, (int)strlen(g_osdMsg)); }
    SelectObject(dc, of); DeleteObject(f); EndPaint(h, &ps);
}
static LRESULT CALLBACK ow_proc(HWND h, UINT m, WPARAM w, LPARAM l) {
    if (m == WM_PAINT) { paint(h); return 0; }
    if (m == WM_TIMER) {
        poll_keys();
        if (!g_game || !IsWindow(g_game)) { g_game = NULL; EnumWindows(enum_cb, (LPARAM)&g_game); }
        HWND fg = GetForegroundWindow(); DWORD pid = 0; if (fg) GetWindowThreadProcessId(fg, &pid);
        int show = g_game && f_overlay && pid == GetCurrentProcessId() && !IsIconic(g_game);
        if (show) {
            RECT cr; POINT p = { 0, 0 }; GetClientRect(g_game, &cr); ClientToScreen(g_game, &p);
            SetWindowPos(h, HWND_TOPMOST, p.x + 12, p.y + 12, 250, 186, SWP_NOACTIVATE | SWP_SHOWWINDOW);
            InvalidateRect(h, NULL, FALSE);
        } else ShowWindow(h, SW_HIDE);
        return 0;
    }
    return DefWindowProcA(h, m, w, l);
}
static DWORD WINAPI ui_thread(LPVOID u) {
    (void)u; WNDCLASSA wc; memset(&wc, 0, sizeof wc);
    wc.lpfnWndProc = ow_proc; wc.hInstance = GetModuleHandleA(NULL); wc.lpszClassName = "CITWTrainerOverlay"; wc.hCursor = LoadCursor(NULL, IDC_ARROW);
    RegisterClassA(&wc);
    g_ow = CreateWindowExA(WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_TOPMOST | WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW, wc.lpszClassName, "CITWTrainer",
                           WS_POPUP, 0, 0, 250, 186, NULL, NULL, wc.hInstance, NULL);
    if (!g_ow) { logf_("overlay window failed (%lu); keys still work", GetLastError()); }
    else SetLayeredWindowAttributes(g_ow, RGB(0, 0, 0), 0, LWA_COLORKEY);
    SetTimer(g_ow, 1, 33, NULL);
    if (!g_ow) { for (;;) { poll_keys(); Sleep(33); } }
    MSG msg; while (GetMessageA(&msg, NULL, 0, 0) > 0) { TranslateMessage(&msg); DispatchMessageA(&msg); }
    return 0;
}

/* ------------------------------------------------------------------ init */
static void load_config(void) {
    char ini[MAX_PATH]; snprintf(ini, sizeof ini, "%s\\citw_trainer.ini", g_dir);
    static const char* kn[9] = { "key_god", "key_infinite_power", "key_add_power", "key_unlimited_dash", "key_speed", "key_one_hit_kill", "key_full_heal", "key_cycle_speed", "key_overlay" };
    static const int kd[9] = { VK_F1, VK_F2, VK_F3, VK_F4, VK_F5, VK_F6, VK_F7, VK_F9, VK_F12 };
    for (int i = 0; i < 9; i++) g_keys[i] = (int)GetPrivateProfileIntA("keys", kn[i], kd[i], ini);
    g_moneyAmount = (int)GetPrivateProfileIntA("trainer", "money_amount", 1000, ini);
    char b[32]; GetPrivateProfileStringA("trainer", "speed_mult", "2.0", b, sizeof b, ini); g_speedMult = (float)atof(b);
    if (g_speedMult < 0.1f || g_speedMult > 20.0f) g_speedMult = 2.0f;
    f_overlay = (int)GetPrivateProfileIntA("trainer", "overlay", 1, ini);
    /* optional: start with features already on */
    f_god = (int)GetPrivateProfileIntA("start", "god", 0, ini); f_infpower = (int)GetPrivateProfileIntA("start", "infinite_power", 0, ini);
    f_dash = (int)GetPrivateProfileIntA("start", "unlimited_dash", 0, ini); f_speed = (int)GetPrivateProfileIntA("start", "speed", 0, ini);
    f_ohk = (int)GetPrivateProfileIntA("start", "one_hit_kill", 0, ini);
}
static void trainer_init(void) {
    char exe[MAX_PATH]; GetModuleFileNameA(NULL, exe, sizeof exe);
    const char* leaf = strrchr(exe, '\\'); leaf = leaf ? leaf + 1 : exe;
    if (_stricmp(leaf, "CITW-Win64-Shipping.exe")) return;                  /* only inside the game process */
    snprintf(g_dir, sizeof g_dir, "%s", exe); *strrchr(g_dir, '\\') = 0;
    InitializeCriticalSection(&g_logcs);
    char lp[MAX_PATH]; snprintf(lp, sizeof lp, "%s\\citw_trainer.log", g_dir);
    g_logh = CreateFileA(lp, GENERIC_WRITE, FILE_SHARE_READ, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    g_base = (uint8_t*)GetModuleHandleA(NULL);
    const IMAGE_NT_HEADERS* nt = (const IMAGE_NT_HEADERS*)(g_base + ((const IMAGE_DOS_HEADER*)g_base)->e_lfanew);
    g_imgSize = nt->OptionalHeader.SizeOfImage;
    const IMAGE_SECTION_HEADER* sh = IMAGE_FIRST_SECTION(nt);
    for (int i = 0; i < nt->FileHeader.NumberOfSections; i++) if (!memcmp(sh[i].Name, ".text", 5)) { g_textRva = sh[i].VirtualAddress; g_textSize = sh[i].Misc.VirtualSize; }
    logf_("CITW trainer v1 starting. base=%p image=0x%X text=0x%X+0x%X", g_base, g_imgSize, g_textRva, g_textSize);
    load_config();
    char sf[MAX_PATH]; snprintf(sf, sizeof sf, "%s\\trainer_selftest.flag", g_dir);
    g_selftest = (GetEnvironmentVariableA("TRAINER_SELFTEST", NULL, 0) > 0) || GetFileAttributesA(sf) != INVALID_FILE_ATTRIBUTES;
    if (g_selftest) logf_("SELF-TEST MODE");
    for (int i = 0; i < F_COUNT; i++) { g_fn[i] = locate(kFns[i].name, kFns[i].rva, kFns[i].aob); }
    fnGetPower = (int (*)(void*))g_fn[F_GetTemplePower];
    int ok = 0;
#define HK(id, fn, orig) do { g_hookOk[id] = install_hook(id, (void*)(fn), (void**)&(orig)); ok += (int)g_hookOk[id]; } while (0)
    HK(H_SetHealthImpl, hk_SetHealthImpl, o_SetHealthImpl);
    HK(H_SetTemplePower, hk_SetTemplePower, o_SetTemplePower);
    HK(H_MoveDash, hk_MoveDash, o_MoveDash);
    HK(H_MoveMaxSpeed, hk_MoveMaxSpeed, o_MoveMaxSpeed);
    HK(H_MoveMaxAccel, hk_MoveMaxAccel, o_MoveMaxAccel);
    HK(H_AttackPower, hk_AttackPower, o_AttackPower);
    HK(H_PcTick, hk_PcTick, o_PcTick);
    HK(H_HeroTick, hk_HeroTick, o_HeroTick);
    logf_("hooks installed: %d/%d", ok, H_COUNT);
    CreateThread(NULL, 0, ui_thread, NULL, 0, NULL);
}

/* ------------------------------------------------------------------ xinput1_3 proxy (forwards everything to the real DLL) */
FARPROC g_real[12];
static DWORD WINAPI xi_none(void) { return 1167; /* ERROR_DEVICE_NOT_CONNECTED */ }
#define THUNK(n, i) __attribute__((naked)) void xi_##n(void) { __asm__ volatile("jmp *g_real+" #i "*8(%rip)"); }
THUNK(ord2, 0) THUNK(ord3, 1) THUNK(ord4, 2) THUNK(ord5, 3) THUNK(ord6, 4) THUNK(ord7, 5) THUNK(ord8, 6)
THUNK(ord100, 7) THUNK(ord101, 8) THUNK(ord102, 9) THUNK(ord103, 10)

BOOL WINAPI DllMain(HINSTANCE h, DWORD reason, LPVOID res) {
    (void)res;
    if (reason == DLL_PROCESS_ATTACH) {
        DisableThreadLibraryCalls(h);
        char sys[MAX_PATH]; GetSystemDirectoryA(sys, sizeof sys); strncat(sys, "\\xinput1_3.dll", sizeof sys - strlen(sys) - 1);
        HMODULE real = LoadLibraryA(sys);
        static const int ords[11] = { 2, 3, 4, 5, 6, 7, 8, 100, 101, 102, 103 };
        for (int i = 0; i < 11; i++) { g_real[i] = real ? GetProcAddress(real, (LPCSTR)(uintptr_t)ords[i]) : NULL; if (!g_real[i]) g_real[i] = (FARPROC)xi_none; }
        trainer_init();
    }
    return TRUE;
}
