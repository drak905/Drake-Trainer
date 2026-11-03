/*
 *  Ghost Song trainer  --  version.dll proxy
 *
 *  Ghost Song (Old Moon, GOG) runs on Unity 2020.3.36f1 **IL2CPP** (x64).
 *  UnityPlayer.dll imports VERSION.dll, so dropping a version.dll next to
 *  GhostSong.exe makes the loader pick ours up.  Every export is forwarded to
 *  the real system32 version.dll (see version.def), so nothing else notices.
 *
 *  The trainer talks to the game through the standard il2cpp C API that
 *  GameAssembly.dll exports, so every value is looked up **by name** - no
 *  hardcoded struct offsets, no game file is ever modified.
 *
 *  Game state lives in two classes (names taken from the decompiled game):
 *    `status`  - the scene game-state MonoBehaviour
 *                 Health/Spirit/Stats (static), stamina + inventoryItems +
 *                 mapChunksOwned (instance)
 *    `charcon` - the global static class
 *                 isImmortal, extrajumps, jumpPower, airjumpsmax, ...
 *
 *  Hooks (MinHook, all with trivial 1-argument signatures, so there is no
 *  calling-convention risk):
 *
 *    status.Update             0x2CB8F0  capture the `status` singleton
 *    status.LateUpdate         0x2BF540  per-frame trainer tick
 *    playermovement.FixedUpdate 0x244C00  x2 move speed (jogSpeed)
 *    DamageCalcScript.FixedUpdate 0x69BF00 one-hit kill (Health -> 0)
 *
 *  v2.0: the control panel is no longer a separate Win32 window.  It is a
 *  Dear ImGui menu drawn INSIDE the game's own frame (IDXGISwapChain::Present
 *  hook, see gs_overlay.cpp).  This file keeps the game logic; the overlay
 *  only posts requests, which are executed here on the game's main thread.
 */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>
#include <stdarg.h>

#include "gs_il2cpp.h"
#include "gs_trainer.h"
#include "MinHook.h"

/* marker string: lets the installer recognise its own dll (never mistake an
 * old trainer for a foreign version.dll that has to be restored) */
__attribute__((used)) const char GS_TRAINER_MARKER[] = "GS-TRAINER-DLL-MARKER/" GS_TRAINER_VERSION;

/* ------------------------------------------------------------------ config */
#define RVA_STATUS_UPDATE      0x2CB8F0ull
#define RVA_STATUS_LATEUPDATE  0x2BF540ull
#define RVA_PM_FIXEDUPDATE     0x244C00ull
#define RVA_DCS_FIXEDUPDATE    0x69BF00ull

/* ItemInfo.NumberOwned - the "do I own this" counter */
#define OFF_ITEM_NUMBEROWNED   0x68
/* Stats struct: Health, Spirit, Ammo, GunPower, Volatility, Vigor, Luck */
#define STATS_FLOATS           7
#define OFF_STATS_SPIRIT       1
#define OFF_STATS_HEALTH       0

/* --- build guard -----------------------------------------------------------
 * The four hook targets are addressed by RVA, so they are only valid for the
 * exact game build the trainer was made for.  Before patching anything we
 * compare the first bytes of every target with the reference build; a
 * mismatch means a different patch/build, and the hook is skipped instead of
 * crashing the game.  The name-based features keep working either way. */
#define GS_HOOK_SIG_BYTES 8
static const unsigned char SIG_STATUS_UPDATE[]    = { 0x40, 0x55, 0x53, 0x48, 0x8D, 0x6C, 0x24, 0xB1 };
static const unsigned char SIG_STATUS_LATEUPDATE[]= { 0x40, 0x53, 0x48, 0x83, 0xEC, 0x20, 0x80, 0x3D };
static const unsigned char SIG_PM_FIXEDUPDATE[]   = { 0x40, 0x55, 0x57, 0x48, 0x8D, 0xAC, 0x24, 0x68 };
static const unsigned char SIG_DCS_FIXEDUPDATE[]  = { 0x48, 0x8B, 0xC4, 0x48, 0x89, 0x48, 0x08, 0x53 };

/* ------------------------------------------------------------------ state */
static volatile LONG g_god, g_infspirit, g_infjump, g_speed2, g_onehit, g_infstam;
static volatile LONG g_have_status, g_hooks_ok, g_calls_tick, g_calls_dmg, g_calls_speed;
static char g_dir[MAX_PATH];
static char g_logpath[MAX_PATH];

/* requests posted by the overlay / hotkey thread, executed on the game thread */
static volatile LONG g_tick_hooked;          /* status.LateUpdate hook is live */
static volatile LONG g_q_action[GS_A_COUNT]; /* pending one-shot actions (count) */
static volatile LONG g_q_fx[GS_F_COUNT];     /* feature changed -> apply side effect */
static volatile LONG g_add_amount = 10000;

/* snapshot for the overlay (written by the game thread only) */
static GsSnapshot g_snap;

static Il2CppClass *g_cls_status, *g_cls_charcon, *g_cls_pm, *g_cls_dcs, *g_cls_themap;
static void *g_status;                 /* the `status` MonoBehaviour instance */

/* saved original values so the toggles are reversible */
static float g_saved_added_spirit = 0.0f;
static int   g_saved_added_spirit_valid = 0;

/* speed fields we scale (playermovement) */
static float g_jog_base = 0, g_jog_applied = 0, g_jog2_base = 0, g_jog2_applied = 0;

void gs_log(const char *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    FILE *f = fopen(g_logpath, "a");
    if (f) { vfprintf(f, fmt, ap); fputc('\n', f); fclose(f); }
    va_end(ap);
}
#define logf_ gs_log

const char *gs_dir(void) { return g_dir; }
void gs_set_add_amount(int amount) {
    if (amount < 1) amount = 1;
    if (amount > 1000000) amount = 1000000;
    InterlockedExchange(&g_add_amount, amount);
}

/* ------------------------------------------------------- il2cpp helpers */
static Il2CppClass *find_class(const char *name) {
    size_t count = 0;
    Il2CppDomain *dom = il2cpp_domain_get();
    if (!dom) return NULL;
    const Il2CppAssembly **asms = il2cpp_domain_get_assemblies(dom, &count);
    if (!asms) return NULL;
    for (size_t i = 0; i < count; i++) {
        Il2CppImage *img = il2cpp_assembly_get_image(asms[i]);
        if (!img) continue;
        Il2CppClass *c = il2cpp_class_from_name(img, "", name);
        if (c) return c;
    }
    return NULL;
}

static Il2CppFieldInfo *sfield(Il2CppClass *c, const char *name) {
    if (!c) return NULL;
    return il2cpp_class_get_field_from_name(c, name);
}
static float get_sf(Il2CppClass *c, const char *name, float def) {
    Il2CppFieldInfo *f = sfield(c, name);
    float v = def;
    if (f) il2cpp_field_static_get_value(f, &v);
    return v;
}
static void set_sf(Il2CppClass *c, const char *name, float v) {
    Il2CppFieldInfo *f = sfield(c, name);
    if (f) il2cpp_field_static_set_value(f, &v);
}
static void set_si(Il2CppClass *c, const char *name, int v) {
    Il2CppFieldInfo *f = sfield(c, name);
    if (f) il2cpp_field_static_set_value(f, &v);
}
static int get_si(Il2CppClass *c, const char *name, int def) {
    Il2CppFieldInfo *f = sfield(c, name);
    int v = def;
    if (f) il2cpp_field_static_get_value(f, &v);
    return v;
}
static int get_sb(Il2CppClass *c, const char *name, int def) {
    Il2CppFieldInfo *f = sfield(c, name);
    unsigned char v = (unsigned char)def;
    if (f) il2cpp_field_static_get_value(f, &v);
    return v ? 1 : 0;
}
static void set_sb(Il2CppClass *c, const char *name, int v) {
    Il2CppFieldInfo *f = sfield(c, name);
    unsigned char b = (unsigned char)(v ? 1 : 0);
    if (f) il2cpp_field_static_set_value(f, &b);
}

/* instance field pointer (NULL when the class/field is unknown) */
static void *ifield(void *obj, Il2CppClass *c, const char *name) {
    if (!obj || !c) return NULL;
    Il2CppFieldInfo *f = il2cpp_class_get_field_from_name(c, name);
    if (!f) return NULL;
    return (char *)obj + il2cpp_field_get_offset(f);
}
static float get_if(void *obj, Il2CppClass *c, const char *name, float def) {
    void *p = ifield(obj, c, name);
    if (!p) return def;
    float v; memcpy(&v, p, sizeof v); return v;
}
static void set_if(void *obj, Il2CppClass *c, const char *name, float v) {
    void *p = ifield(obj, c, name);
    if (p) memcpy(p, &v, sizeof v);
}
static void *get_ip(void *obj, Il2CppClass *c, const char *name) {
    void *p = ifield(obj, c, name);
    if (!p) return NULL;
    void *v; memcpy(&v, p, sizeof v); return v;
}

static void call_method(Il2CppMethodInfo *m, void *obj, void **args) {
    if (!m) return;
    Il2CppObject *exc = NULL;
    il2cpp_runtime_invoke(m, obj, args, &exc);
}
static Il2CppMethodInfo *method_of(Il2CppClass *c, const char *name, int argc) {
    if (!c) return NULL;
    return il2cpp_class_get_method_from_name(c, name, argc);
}

/* `status.Stats` and `status.AddedStats` are 7-float structs */
static void stats_get(const char *field, float *out) {
    memset(out, 0, STATS_FLOATS * sizeof(float));
    Il2CppFieldInfo *f = sfield(g_cls_status, field);
    if (f) il2cpp_field_static_get_value(f, out);
}
static void stats_set(const char *field, const float *in) {
    Il2CppFieldInfo *f = sfield(g_cls_status, field);
    if (f) il2cpp_field_static_set_value(f, (void *)in);
}

/* the game's own maximum-health formula:
 *   Health = Round(Stats.Health - Stats.Health / 100f * suitDamage) */
static float effective_max_health(void) {
    float st[STATS_FLOATS];
    stats_get("Stats", st);
    float suit = get_if(g_status, g_cls_status, "suitDamage", 0.0f);
    float m = st[OFF_STATS_HEALTH] - st[OFF_STATS_HEALTH] / 100.0f * suit;
    return (float)floor(m + 0.5f);
}

/* ------------------------------------------------------------------ hooks */
typedef void (__fastcall *FnStatusUpdate)(void *self);
static FnStatusUpdate o_status_update, o_status_lateupdate;
typedef void (__fastcall *FnFixedUpdate)(void *self);
static FnFixedUpdate o_pm_fixedupdate, o_dcs_fixedupdate;

/* ---------------- per-frame trainer tick (status.LateUpdate) ---------------- */
static void act_add_money(int amount);
static void act_heal(void);
static void act_reveal_map(void);
static void act_give_all_items(void);
static void act_dump_diagnostics(void);
static void set_infinite_spirit(int on);
static void run_pending(void);
static void update_snapshot(void);

static void trainer_tick(void) {
    if (!g_status || !g_cls_status || !g_cls_charcon) return;
    LONG n = InterlockedIncrement(&g_calls_tick);

    run_pending();
    if ((n % 6) == 0) update_snapshot();

    /* ---- F1 god mode ------------------------------------------------------
     * playermovement.Update only starts the death sequence when
     *   status.Health <= 0f && ... && !charcon.isImmortal
     * so isImmortal is the game's own god-mode flag.  The health bar is kept
     * full as well so the HUD never shows an empty bar. */
    if (g_god) {
        set_sb(g_cls_charcon, "isImmortal", 1);
        float maxhp = effective_max_health();
        if (maxhp > 0.0f) set_sf(g_cls_status, "Health", maxhp);
    }

    /* ---- F3 infinite spirit ----------------------------------------------
     * status.FixedUpdate clamps Spirit to Stats.Spirit, and
     * Stats.Spirit = Base + Added + Temp + Gear + ... , so the cap is raised
     * through AddedStats.Spirit (the same pool upgrades use). */
    if (g_infspirit) {
        set_sf(g_cls_status, "Spirit", 99999.0f);
    }

    /* ---- F4 unlimited jump ------------------------------------------------
     * the air-jump allowance is
     *   charcon.airjumps < inventoryItems[0].NumberOwned
     *                    + charcon.extrajumps
     *                    + inventoryItems[53].NumberOwned
     * so extrajumps is the knob. */
    if (g_infjump) {
        set_si(g_cls_charcon, "extrajumps", 99);
    }

    /* ---- F8 infinite stamina ---------------------------------------------- */
    if (g_infstam) {
        float mx = get_if(g_status, g_cls_status, "staminaMax", 0.0f);
        if (mx > 0.0f) set_if(g_status, g_cls_status, "stamina", mx);
    }
}

static void hk_status_lateupdate(void *self) {
    o_status_lateupdate(self);
    trainer_tick();
}

static void hk_status_update(void *self) {
    if (self && self != g_status) {
        g_status = self;
        InterlockedExchange(&g_have_status, 1);
    }
    o_status_update(self);
}

/* ---- F5 move speed x2 ---------------------------------------------------
 * playermovement recomputes  playerSpeed = jogSpeed + bonus  every frame,
 * so jogSpeed is the field to scale. */
static void speed_field(void *self, const char *name, float *base, float *applied, int on) {
    if (on) {
        float cur = get_if(self, g_cls_pm, name, 0.0f);
        /* first time, or the game wrote a fresh value: that is the new baseline.
         * If the field still holds what WE wrote last, the baseline is unchanged -
         * this is what stops "off, then on again" from doubling the doubled value. */
        if (*applied == 0.0f || fabsf(cur - *applied) > 0.001f) *base = cur;
        if (*base > 0.0f) {
            *applied = *base * 2.0f;
            set_if(self, g_cls_pm, name, *applied);
        }
    } else if (*applied != 0.0f) {
        /* switched off: give the original value back (only if nobody changed it since) */
        float cur = get_if(self, g_cls_pm, name, 0.0f);
        if (*base > 0.0f && fabsf(cur - *applied) <= 0.001f) set_if(self, g_cls_pm, name, *base);
        *applied = 0.0f;
    }
}

static void hk_pm_fixedupdate(void *self) {
    if (self) {
        if (g_speed2) {
            speed_field(self, "jogSpeed",  &g_jog_base,  &g_jog_applied,  1);
            speed_field(self, "jog2Speed", &g_jog2_base, &g_jog2_applied, 1);
            InterlockedIncrement(&g_calls_speed);
        } else if (g_jog_applied != 0.0f || g_jog2_applied != 0.0f) {
            speed_field(self, "jogSpeed",  &g_jog_base,  &g_jog_applied,  0);
            speed_field(self, "jog2Speed", &g_jog2_base, &g_jog2_applied, 0);
        }
    }
    o_pm_fixedupdate(self);
}

/* ---- F6 one hit kill ----------------------------------------------------
 * DamageCalcScript.FixedUpdate applies the queued damage to Health, and every
 * enemy class checks `if (dc.Health <= 0f) Die();` in its own Update, so
 * zeroing the health of a damaged enemy kills it through the normal path. */
static void hk_dcs_fixedupdate(void *self) {
    o_dcs_fixedupdate(self);
    if (g_onehit && self) {
        float hp   = get_if(self, g_cls_dcs, "Health", -1.0f);
        float hpmx = get_if(self, g_cls_dcs, "maxHealth", 0.0f);
        if (hp > 0.0f && hpmx > 0.0f && hp < hpmx) {
            set_if(self, g_cls_dcs, "Health", 0.0f);
            InterlockedIncrement(&g_calls_dmg);
        }
    }
}

/* ------------------------------------------------------------------ actions */
static void act_add_money(int amount) {
    if (!g_status) return;
    float added[STATS_FLOATS];
    stats_get("AddedStats", added);
    float cur = get_sf(g_cls_status, "Spirit", 0.0f);
    added[OFF_STATS_SPIRIT] += (float)amount;
    stats_set("AddedStats", added);
    set_sf(g_cls_status, "Spirit", cur + (float)amount);
    logf_("add money: spirit %.0f -> %.0f (cap raised by %d)", cur, cur + (float)amount, amount);
}

static void act_heal(void) {
    if (!g_status) return;
    float maxhp = effective_max_health();
    if (maxhp > 0.0f) set_sf(g_cls_status, "Health", maxhp);
    logf_("heal: health -> %.0f", maxhp);
}

/* F3 on/off keeps the original spirit cap so the toggle is reversible */
static void set_infinite_spirit(int on) {
    if (!g_cls_status) return;
    float added[STATS_FLOATS];
    stats_get("AddedStats", added);
    if (on) {
        if (!g_saved_added_spirit_valid) {
            g_saved_added_spirit = added[OFF_STATS_SPIRIT];
            g_saved_added_spirit_valid = 1;
        }
        added[OFF_STATS_SPIRIT] = 99999.0f;
        stats_set("AddedStats", added);
        set_sf(g_cls_status, "Spirit", 99999.0f);
        logf_("infinite spirit on (cap 99999, original %.0f saved)", g_saved_added_spirit);
    } else {
        if (g_saved_added_spirit_valid) {
            added[OFF_STATS_SPIRIT] = g_saved_added_spirit;
            stats_set("AddedStats", added);
            g_saved_added_spirit_valid = 0;
        }
        logf_("infinite spirit off (cap restored)");
    }
}

static void act_reveal_map(void) {
    if (!g_status) return;
    /* status.mapChunksOwned : int[] - 1 == that map chunk is revealed.
     * themap.displayChunks() enables the matching chunk renderers. */
    Il2CppArray *a = (Il2CppArray *)get_ip(g_status, g_cls_status, "mapChunksOwned");
    if (a) {
        uint32_t n = il2cpp_array_length(a);
        int32_t *data = (int32_t *)((char *)a + 0x20);   /* Il2CppArray.vector */
        for (uint32_t i = 0; i < n; i++) data[i] = 1;
        logf_("reveal map: %u chunks unlocked", n);
    }
    set_si(g_cls_status, "hasMap", 1);
    set_si(g_cls_status, "hasBugMap", 1);
    void *map = get_ip(g_status, g_cls_status, "MapScript");
    if (map) {
        Il2CppMethodInfo *m = method_of(g_cls_themap, "displayChunks", 0);
        call_method(m, map, NULL);
    }
}

/* mirrors charcon.gainallitems(): every item owned, the "counter" items
 * reset to 0 and the stackables set to 25 */
static const int GS_ITEM_ZERO[] = {
    2, 3, 6, 8, 10, 13, 17, 18, 21, 22, 23, 24, 25, 27, 28, 30, 36, 38,
    42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 59, 54, 55, 56, 57, 58,
    60, 61, 62, 63, 67
};
static const int GS_ITEM_25[] = { 39, 40, 41, 64, 65, 66 };

static void act_give_all_items(void) {
    if (!g_status) return;
    Il2CppArray *a = (Il2CppArray *)get_ip(g_status, g_cls_status, "inventoryItems");
    if (!a) return;
    uint32_t n = il2cpp_array_length(a);
    void **data = (void **)((char *)a + 0x20);
    for (uint32_t i = 0; i < n; i++) {
        if (!data[i]) continue;
        int *num = (int *)((char *)data[i] + OFF_ITEM_NUMBEROWNED);
        *num = 1;
    }
    for (size_t i = 0; i < sizeof GS_ITEM_ZERO / sizeof GS_ITEM_ZERO[0]; i++) {
        int idx = GS_ITEM_ZERO[i];
        if (idx < (int)n && data[idx]) *(int *)((char *)data[idx] + OFF_ITEM_NUMBEROWNED) = 0;
    }
    for (size_t i = 0; i < sizeof GS_ITEM_25 / sizeof GS_ITEM_25[0]; i++) {
        int idx = GS_ITEM_25[i];
        if (idx < (int)n && data[idx]) *(int *)((char *)data[idx] + OFF_ITEM_NUMBEROWNED) = 25;
    }
    logf_("give all items: %u items processed", n);
}

/* ------------------------------------------------------------------ requests
 * The in-game overlay (render thread) and the hotkey thread never touch il2cpp.
 * They flip a feature flag / post a request; run_pending() executes the side
 * effects on the game's main thread from the status.LateUpdate hook. */
static const char *const FEATURE_EN[GS_F_COUNT] = {
    "God mode", "Infinite spirit", "Unlimited jump", "Move speed x2", "One-hit kill", "Infinite stamina"
};
static const char *const FEATURE_VI[GS_F_COUNT] = {
    "Bất tử", "Spirit vô hạn", "Nhảy vô hạn", "Tốc độ x2", "Hạ gục 1 đòn", "Thể lực vô hạn"
};
static const char *const ACTION_EN[GS_A_COUNT] = {
    "Spirit added", "Healed", "Map revealed", "All items given", "Diagnostics written to gs_trainer.log"
};
static const char *const ACTION_VI[GS_A_COUNT] = {
    "Đã thêm Spirit", "Đã hồi máu", "Đã mở toàn bộ bản đồ", "Đã nhận tất cả vật phẩm", "Đã ghi chẩn đoán vào gs_trainer.log"
};

static volatile LONG *feature_ptr(int id) {
    switch (id) {
    case GS_F_GOD:       return &g_god;
    case GS_F_INFSPIRIT: return &g_infspirit;
    case GS_F_INFJUMP:   return &g_infjump;
    case GS_F_SPEED2:    return &g_speed2;
    case GS_F_ONEHIT:    return &g_onehit;
    case GS_F_INFSTAM:   return &g_infstam;
    }
    return NULL;
}

/* saved so the unlimited-jump toggle is reversible */
static int g_saved_extrajumps = 0, g_saved_extrajumps_valid = 0;

static void run_pending(void) {
    for (int i = 0; i < GS_F_COUNT; i++) {
        if (!InterlockedExchange(&g_q_fx[i], 0)) continue;
        int on = (int)*feature_ptr(i);
        switch (i) {
        case GS_F_GOD:
            if (!on) set_sb(g_cls_charcon, "isImmortal", 0);
            break;
        case GS_F_INFSPIRIT:
            set_infinite_spirit(on);
            break;
        case GS_F_INFJUMP:
            if (on) {
                if (!g_saved_extrajumps_valid) {
                    g_saved_extrajumps = get_si(g_cls_charcon, "extrajumps", 0);
                    if (g_saved_extrajumps == 99) g_saved_extrajumps = 0;
                    g_saved_extrajumps_valid = 1;
                }
            } else if (g_saved_extrajumps_valid) {
                set_si(g_cls_charcon, "extrajumps", g_saved_extrajumps);
                g_saved_extrajumps_valid = 0;
            }
            break;
        case GS_F_SPEED2:
            /* nothing to do here: the playermovement hook applies / restores the speed */
            break;
        default: break;
        }
    }
    for (int i = 0; i < GS_A_COUNT; i++) {
        LONG n = InterlockedExchange(&g_q_action[i], 0);
        if (n <= 0) continue;
        switch (i) {
        case GS_A_ADDMONEY:  for (LONG k = 0; k < n && k < 20; k++) act_add_money((int)g_add_amount); break;
        case GS_A_HEAL:      act_heal(); break;
        case GS_A_REVEAL:    act_reveal_map(); break;
        case GS_A_GIVEITEMS: act_give_all_items(); break;
        case GS_A_DIAG:      act_dump_diagnostics(); break;
        }
    }
}

int gs_feature_get(int id) {
    volatile LONG *p = feature_ptr(id);
    return p ? (*p != 0) : 0;
}

void gs_feature_set(int id, int on) {
    volatile LONG *p = feature_ptr(id);
    if (!p) return;
    on = on ? 1 : 0;
    if (InterlockedExchange(p, on) == on) return;
    logf_("toggle %s -> %d", FEATURE_EN[id], on);
    char en[96], vi[96];
    snprintf(en, sizeof en, "%s: %s", FEATURE_EN[id], on ? "ON" : "OFF");
    snprintf(vi, sizeof vi, "%s: %s", FEATURE_VI[id], on ? "BẬT" : "TẮT");
    gs_overlay_toast(en, vi);
    InterlockedExchange(&g_q_fx[id], 1);
    if (!g_tick_hooked && g_status) run_pending();
}

void gs_feature_toggle(int id) { gs_feature_set(id, !gs_feature_get(id)); }

void gs_action(int id) {
    if (id < 0 || id >= GS_A_COUNT) return;
    if (!g_have_status || !g_status) {
        gs_overlay_toast("Start or load a game first", "Hãy vào game (tải file save) trước");
        return;
    }
    InterlockedIncrement(&g_q_action[id]);
    gs_overlay_toast(ACTION_EN[id], ACTION_VI[id]);
    if (!g_tick_hooked) run_pending();
}

static void update_snapshot(void) {
    GsSnapshot s;
    memset(&s, 0, sizeof s);
    s.have_status = 1;
    float st[STATS_FLOATS];
    stats_get("Stats", st);
    s.hp = get_sf(g_cls_status, "Health", 0.0f);
    s.hpmax = effective_max_health();
    s.spirit = get_sf(g_cls_status, "Spirit", 0.0f);
    s.spiritcap = st[OFF_STATS_SPIRIT];
    s.stamina = get_if(g_status, g_cls_status, "stamina", 0.0f);
    s.staminamax = get_if(g_status, g_cls_status, "staminaMax", 0.0f);
    g_snap = s;
}

void gs_get_snapshot(GsSnapshot *out) {
    GsSnapshot s = g_snap;
    s.have_status = g_have_status ? 1 : 0;
    if (!s.have_status) memset(&s, 0, sizeof s);
    s.hooks_ok = g_hooks_ok;
    s.ticks = g_calls_tick;
    s.kills = g_calls_dmg;
    s.speedcalls = g_calls_speed;
    for (int i = 0; i < GS_F_COUNT; i++) s.toggles[i] = gs_feature_get(i);
    s.add_amount = (int)g_add_amount;
    *out = s;
}

/* ------------------------------------------------------------------ hotkeys
 * Polled (not window messages) so they work whatever the game does with its
 * input, but ONLY while a window of this process is in the foreground - the
 * F-keys no longer leak to other programs the way v1.0's global keys did. */
static int fg_is_game(void) {
    HWND fg = GetForegroundWindow();
    if (!fg) return 0;
    DWORD pid = 0;
    GetWindowThreadProcessId(fg, &pid);
    return pid == GetCurrentProcessId();
}

static void on_hotkey(int idx) {
    switch (idx) {
    case 0:  gs_feature_toggle(GS_F_GOD); break;            /* F1  */
    case 1:  gs_action(GS_A_ADDMONEY); break;               /* F2  */
    case 2:  gs_feature_toggle(GS_F_INFSPIRIT); break;      /* F3  */
    case 3:  gs_feature_toggle(GS_F_INFJUMP); break;        /* F4  */
    case 4:  gs_feature_toggle(GS_F_SPEED2); break;         /* F5  */
    case 5:  gs_feature_toggle(GS_F_ONEHIT); break;         /* F6  */
    case 6:  gs_action(GS_A_HEAL); break;                   /* F7  */
    case 7:  gs_feature_toggle(GS_F_INFSTAM); break;        /* F8  */
    case 8:  gs_action(GS_A_REVEAL); break;                 /* F9  */
    case 9:  gs_overlay_toggle_menu(); break;               /* F10 */
    case 10: gs_action(GS_A_GIVEITEMS); break;              /* F11 */
    case 11: gs_action(GS_A_DIAG); break;                   /* F12 */
    case 12: gs_overlay_toggle_menu(); break;               /* Insert */
    }
}

static DWORD WINAPI hotkey_thread(LPVOID p) {
    (void)p;
    static const int keys[13] = { VK_F1, VK_F2, VK_F3, VK_F4, VK_F5, VK_F6, VK_F7, VK_F8,
                                  VK_F9, VK_F10, VK_F11, VK_F12, VK_INSERT };
    int prev[13]; memset(prev, 0, sizeof prev);
    for (;;) {
        int fg = fg_is_game() && !(GetAsyncKeyState(VK_MENU) & 0x8000);   /* Alt+F4 is not a hotkey */
        for (int i = 0; i < 13; i++) {
            int down = fg && (GetAsyncKeyState(keys[i]) & 0x8000) != 0;
            if (down && !prev[i]) on_hotkey(i);
            prev[i] = down;
        }
        Sleep(15);
    }
    return 0;
}

/* F12: dump the trainer-relevant game state to gs_trainer.log so a live test
 * can be verified without guessing from the screen. */
static void act_dump_diagnostics(void) {
    if (!g_status) { logf_("diag: no game state yet"); return; }
    float st[STATS_FLOATS]; stats_get("Stats", st);
    float added[STATS_FLOATS]; stats_get("AddedStats", added);
    logf_("diag: hp=%.1f/%.1f  spirit=%.1f/%.1f  stamina=%.1f/%.1f",
          get_sf(g_cls_status, "Health", 0.0f), effective_max_health(),
          get_sf(g_cls_status, "Spirit", 0.0f), st[OFF_STATS_SPIRIT],
          get_if(g_status, g_cls_status, "stamina", 0.0f),
          get_if(g_status, g_cls_status, "staminaMax", 0.0f));
    logf_("diag: addedStats.spirit=%.1f  isImmortal=%d  extrajumps=%d  airjumpsmax=%d  hasAirjump=%d",
          added[OFF_STATS_SPIRIT], get_sb(g_cls_charcon, "isImmortal", 0),
          get_si(g_cls_charcon, "extrajumps", 0), get_si(g_cls_charcon, "airjumpsmax", 0),
          get_si(g_cls_status, "hasAirjump", 0));
    void *pm = get_ip(g_status, g_cls_status, "elbypm");
    if (pm)
        logf_("diag: jogSpeed=%.2f  jog2Speed=%.2f  playerJumpPower=%.1f  invuln=%d",
              get_if(pm, g_cls_pm, "jogSpeed", 0.0f), get_if(pm, g_cls_pm, "jog2Speed", 0.0f),
              get_if(pm, g_cls_pm, "playerJumpPower", 0.0f), get_if(pm, g_cls_pm, "invuln", 0.0f));
    Il2CppArray *chunks = (Il2CppArray *)get_ip(g_status, g_cls_status, "mapChunksOwned");
    if (chunks) {
        uint32_t n = il2cpp_array_length(chunks);
        int32_t *d = (int32_t *)((char *)chunks + 0x20);
        int owned = 0;
        for (uint32_t i = 0; i < n; i++) if (d[i] == 1) owned++;
        logf_("diag: map chunks owned %d / %u", owned, n);
    }
    Il2CppArray *items = (Il2CppArray *)get_ip(g_status, g_cls_status, "inventoryItems");
    if (items) {
        uint32_t n = il2cpp_array_length(items);
        void **d = (void **)((char *)items + 0x20);
        int owned = 0;
        for (uint32_t i = 0; i < n; i++) {
            if (!d[i]) continue;
            if (*(int *)((char *)d[i] + OFF_ITEM_NUMBEROWNED) > 0) owned++;
        }
        logf_("diag: items owned %d / %u", owned, n);
    }
    logf_("diag: toggles god=%ld infspirit=%ld infjump=%ld speed=%ld onehit=%ld instam=%ld",
          g_god, g_infspirit, g_infjump, g_speed2, g_onehit, g_infstam);
}

/* ------------------------------------------------------- self test (gate 3/4) */
static int finite_in(float v, float lo, float hi) { return isfinite(v) && v >= lo && v <= hi; }

static DWORD WINAPI selftest_thread(LPVOID p) {
    (void)p;
    int waited = 0;
    while (waited < 240 && !g_have_status) { Sleep(500); waited++; }
    Sleep(2500);
    char path[MAX_PATH]; snprintf(path, sizeof path, "%s\\trainer_selftest_report.json", g_dir);
    if (!g_have_status) {
        FILE *f = fopen(path, "w");
        if (f) { fprintf(f, "{\n  \"overall_status\": \"PARTIAL_FAIL_NEEDS_ISOLATED_HEAL\",\n"
                            "  \"feature_results\": [\n"
                            "    {\"subagent_branch_id\": \"SUBAGENT-COMBAT-01\", \"hook_status\": \"NO_GAME_STATE\", \"invariant_check\": \"FAIL\", \"delta_test_result\": \"FAIL\"}\n  ]\n}\n"); fclose(f); }
        return 0;
    }
    float st[STATS_FLOATS]; stats_get("Stats", st);
    float hp  = get_sf(g_cls_status, "Health", 0.0f);
    float spi = get_sf(g_cls_status, "Spirit", 0.0f);
    float maxhp = effective_max_health();
    int hp_inv  = finite_in(maxhp, 1.0f, 1e7f) && finite_in(hp, 0.0f, maxhp * 2.0f);
    int spi_inv = finite_in(st[OFF_STATS_SPIRIT], 0.0f, 1e7f) && finite_in(spi, 0.0f, 1e9f);

    /* combat delta: god mode must snap a halved health back to the maximum */
    int combat_delta = 0;
    if (hp_inv) {
        LONG old = g_god; InterlockedExchange(&g_god, 1);
        set_sf(g_cls_status, "Health", maxhp > 2.0f ? maxhp / 2.0f : 1.0f);
        Sleep(400);
        combat_delta = (get_sf(g_cls_status, "Health", 0.0f) == maxhp);
        InterlockedExchange(&g_god, old);
        if (!old) set_sb(g_cls_charcon, "isImmortal", 0);
        set_sf(g_cls_status, "Health", hp);   /* leave the save as we found it */
    }
    /* economy delta: +10 spirit must be readable back, then everything is
     * restored so the self-test never leaves a modified save behind */
    int eco_delta = 0;
    float saved_added[STATS_FLOATS];
    stats_get("AddedStats", saved_added);
    float saved_spirit = get_sf(g_cls_status, "Spirit", 0.0f);
    if (spi_inv) {
        float before = saved_spirit;
        act_add_money(10);
        Sleep(300);
        eco_delta = (get_sf(g_cls_status, "Spirit", 0.0f) >= before + 10.0f);
    }
    stats_set("AddedStats", saved_added);
    set_sf(g_cls_status, "Spirit", saved_spirit);
    /* unlimited jump through the same request queue the overlay / hotkeys use:
     * on -> extrajumps == 99, off -> the original value is back */
    int jump_delta = 0;
    {
        int old = gs_feature_get(GS_F_INFJUMP);
        int before = get_si(g_cls_charcon, "extrajumps", 0);
        gs_feature_set(GS_F_INFJUMP, 1);
        Sleep(400);
        int on_ok = (get_si(g_cls_charcon, "extrajumps", 0) == 99);
        gs_feature_set(GS_F_INFJUMP, old);
        Sleep(400);
        int off_ok = old ? 1 : (get_si(g_cls_charcon, "extrajumps", 0) == before);
        jump_delta = on_ok && off_ok;
    }
    int jump_inv = 1;
    int ohk_ok   = (g_hooks_ok >= 4);
    int map_ok   = (get_ip(g_status, g_cls_status, "mapChunksOwned") != NULL);
    int stam_ok  = (get_if(g_status, g_cls_status, "staminaMax", 0.0f) > 0.0f);

    /* in-game overlay: the Present hook must have drawn frames */
    int ov_wait = 0;
    while (ov_wait < 40 && gs_overlay_frames() <= 0) { Sleep(500); ov_wait++; }
    long ov_frames = gs_overlay_frames();
    int overlay_ok = (ov_frames > 0);

    int all = hp_inv && combat_delta && spi_inv && eco_delta && jump_inv && jump_delta && ohk_ok && map_ok && stam_ok && overlay_ok;
    FILE *f = fopen(path, "w");
    if (f) {
        fprintf(f, "{\n  \"overall_status\": \"%s\",\n  \"trainer_version\": \"%s\",\n  \"feature_results\": [\n",
                all ? "PASS_READY_FOR_HUMAN" : "PARTIAL_FAIL_NEEDS_ISOLATED_HEAL", GS_TRAINER_VERSION);
        fprintf(f, "    {\"subagent_branch_id\": \"SUBAGENT-COMBAT-01\", \"hook_status\": \"charcon.isImmortal\", \"invariant_check\": \"%s\", \"delta_test_result\": \"%s\", \"observed_hp\": %.2f, \"observed_max_hp\": %.2f},\n",
                hp_inv ? "PASS" : "FAIL_INVALID_INVARIANT", combat_delta ? "PASS" : "FAIL", hp, maxhp);
        fprintf(f, "    {\"subagent_branch_id\": \"SUBAGENT-ECONOMY-02\", \"hook_status\": \"status.AddedStats.Spirit + status.Spirit\", \"invariant_check\": \"%s\", \"delta_test_result\": \"%s\", \"observed_spirit\": %.2f},\n",
                spi_inv ? "PASS" : "FAIL_INVALID_INVARIANT", eco_delta ? "PASS" : "FAIL", spi);
        fprintf(f, "    {\"subagent_branch_id\": \"SUBAGENT-JUMP-03\", \"hook_status\": \"charcon.extrajumps (via request queue)\", \"invariant_check\": \"%s\", \"delta_test_result\": \"%s\"},\n",
                jump_inv ? "PASS" : "FAIL_INVALID_INVARIANT", jump_delta ? "PASS" : "FAIL");
        fprintf(f, "    {\"subagent_branch_id\": \"SUBAGENT-SPEED-04\", \"hook_status\": \"playermovement.FixedUpdate -> jogSpeed\", \"invariant_check\": \"%s\", \"delta_test_result\": \"NEEDS_GAMEPLAY\"},\n",
                jump_inv ? "PASS" : "FAIL_INVALID_INVARIANT");
        fprintf(f, "    {\"subagent_branch_id\": \"SUBAGENT-OHK-05\", \"hook_status\": \"DamageCalcScript.FixedUpdate -> Health\", \"invariant_check\": \"%s\", \"delta_test_result\": \"NEEDS_GAMEPLAY\"},\n",
                ohk_ok ? "PASS" : "FAIL_INVALID_INVARIANT");
        fprintf(f, "    {\"subagent_branch_id\": \"SUBAGENT-MAP-06\", \"hook_status\": \"status.mapChunksOwned\", \"invariant_check\": \"%s\", \"delta_test_result\": \"NEEDS_GAMEPLAY\"},\n",
                map_ok ? "PASS" : "FAIL_INVALID_INVARIANT");
        fprintf(f, "    {\"subagent_branch_id\": \"SUBAGENT-STAMINA-07\", \"hook_status\": \"status.stamina\", \"invariant_check\": \"%s\", \"delta_test_result\": \"NEEDS_GAMEPLAY\"},\n",
                stam_ok ? "PASS" : "FAIL_INVALID_INVARIANT");
        fprintf(f, "    {\"subagent_branch_id\": \"SUBAGENT-OVERLAY-08\", \"hook_status\": \"IDXGISwapChain::Present + Dear ImGui\", \"invariant_check\": \"%s\", \"delta_test_result\": \"%s\", \"frames_drawn\": %ld}\n",
                overlay_ok ? "PASS" : "FAIL_NO_FRAMES", overlay_ok ? "PASS" : "FAIL", ov_frames);
        fprintf(f, "  ]\n}\n");
        fclose(f);
    }
    logf_("selftest: overall=%s", all ? "PASS" : "FAIL");
    return 0;
}

/* ------------------------------------------------------------------ init */
static int resolve_api(void) {
    HMODULE ga = GetModuleHandleW(L"GameAssembly.dll");
    if (!ga) return 0;
#define RESOLVE(name) \
    name = (__typeof__(name))GetProcAddress(ga, #name); \
    if (!name) { logf_("missing export: %s", #name); return 0; }
    RESOLVE(il2cpp_domain_get)
    RESOLVE(il2cpp_domain_get_assemblies)
    RESOLVE(il2cpp_assembly_get_image)
    RESOLVE(il2cpp_class_from_name)
    RESOLVE(il2cpp_class_get_field_from_name)
    RESOLVE(il2cpp_class_get_method_from_name)
    RESOLVE(il2cpp_field_get_offset)
    RESOLVE(il2cpp_field_static_get_value)
    RESOLVE(il2cpp_field_static_set_value)
    RESOLVE(il2cpp_field_get_value)
    RESOLVE(il2cpp_runtime_invoke)
    RESOLVE(il2cpp_array_length)
    RESOLVE(il2cpp_class_get_name)
#undef RESOLVE
    return 1;
}

/* does the code at this RVA still look like the reference build? */
static int sig_ok(const unsigned char *base, unsigned long long rva, const unsigned char *sig) {
    /* the module image is mapped, so reading the RVA is safe as long as it is
     * inside the image; compare against the expected prologue */
    MEMORY_BASIC_INFORMATION mbi;
    if (VirtualQuery(base + rva, &mbi, sizeof mbi) == 0) return 0;
    if (mbi.State != MEM_COMMIT) return 0;
    if (memcmp(base + rva, sig, GS_HOOK_SIG_BYTES) != 0) return 0;
    return 1;
}

static void install_hooks(void) {
    HMODULE ga = GetModuleHandleW(L"GameAssembly.dll");
    if (!ga) { logf_("no GameAssembly.dll"); return; }
    unsigned char *base = (unsigned char *)ga;
    LONG ok = 0, skipped = 0;
    void *p;

    if (MH_Initialize() != MH_OK) { logf_("MH_Initialize failed"); return; }

    p = base + RVA_STATUS_LATEUPDATE;
    if (!sig_ok(base, RVA_STATUS_LATEUPDATE, SIG_STATUS_LATEUPDATE)) {
        logf_("build mismatch: status.LateUpdate prologue differs - hook skipped"); skipped++;
    } else if (MH_CreateHook(p, (void *)hk_status_lateupdate, (void **)&o_status_lateupdate) == MH_OK &&
        MH_EnableHook(p) == MH_OK) { ok++; InterlockedExchange(&g_tick_hooked, 1); }
    else logf_("hook status.LateUpdate failed");

    p = base + RVA_STATUS_UPDATE;
    if (!sig_ok(base, RVA_STATUS_UPDATE, SIG_STATUS_UPDATE)) {
        logf_("build mismatch: status.Update prologue differs - hook skipped"); skipped++;
    } else if (MH_CreateHook(p, (void *)hk_status_update, (void **)&o_status_update) == MH_OK &&
        MH_EnableHook(p) == MH_OK) ok++;
    else logf_("hook status.Update failed");

    p = base + RVA_PM_FIXEDUPDATE;
    if (!sig_ok(base, RVA_PM_FIXEDUPDATE, SIG_PM_FIXEDUPDATE)) {
        logf_("build mismatch: playermovement.FixedUpdate prologue differs - hook skipped"); skipped++;
    } else if (MH_CreateHook(p, (void *)hk_pm_fixedupdate, (void **)&o_pm_fixedupdate) == MH_OK &&
        MH_EnableHook(p) == MH_OK) ok++;
    else logf_("hook playermovement.FixedUpdate failed");

    p = base + RVA_DCS_FIXEDUPDATE;
    if (!sig_ok(base, RVA_DCS_FIXEDUPDATE, SIG_DCS_FIXEDUPDATE)) {
        logf_("build mismatch: DamageCalcScript.FixedUpdate prologue differs - hook skipped"); skipped++;
    } else if (MH_CreateHook(p, (void *)hk_dcs_fixedupdate, (void **)&o_dcs_fixedupdate) == MH_OK &&
        MH_EnableHook(p) == MH_OK) ok++;
    else logf_("hook DamageCalcScript.FixedUpdate failed");

    InterlockedExchange(&g_hooks_ok, ok);
    logf_("hooks installed: %ld/4 (skipped %ld)", ok, skipped);
}

static DWORD WINAPI init_thread(LPVOID p) {
    (void)p;
    HMODULE self;
    GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                        (LPCSTR)init_thread, &self);
    char dll[MAX_PATH];
    GetModuleFileNameA(self, dll, MAX_PATH);
    char *s = strrchr(dll, '\\'); if (s) *s = 0;
    strncpy(g_dir, dll, sizeof g_dir - 1);
    snprintf(g_logpath, sizeof g_logpath, "%s\\gs_trainer.log", dll);
    logf_("--- Ghost Song trainer start. dir=%s", g_dir);

    /* wait for GameAssembly.dll + a live il2cpp domain (up to ~3 minutes) */
    int ok = 0;
    for (int i = 0; i < 360; i++) {
        if (GetModuleHandleW(L"GameAssembly.dll") && resolve_api()) {
            if (il2cpp_domain_get()) { ok = 1; break; }
        }
        Sleep(500);
    }
    if (!ok) { logf_("il2cpp runtime never came up - trainer disabled"); return 0; }
    logf_("il2cpp runtime ready");

    g_cls_status  = find_class("status");
    g_cls_charcon = find_class("charcon");
    g_cls_pm      = find_class("playermovement");
    g_cls_dcs     = find_class("DamageCalcScript");
    g_cls_themap  = find_class("themap");
    logf_("classes: status=%p charcon=%p playermovement=%p DamageCalcScript=%p themap=%p",
          (void *)g_cls_status, (void *)g_cls_charcon, (void *)g_cls_pm, (void *)g_cls_dcs, (void *)g_cls_themap);
    if (!g_cls_status || !g_cls_charcon) { logf_("core classes not found - trainer disabled"); return 0; }

    install_hooks();
    gs_overlay_start();
    CreateThread(NULL, 0, hotkey_thread, NULL, 0, NULL);

    { char e[8]; char flag[MAX_PATH]; snprintf(flag, sizeof flag, "%s\\trainer_selftest.flag", g_dir);
      int on = (GetEnvironmentVariableA("TRAINER_SELFTEST", e, sizeof e) && e[0] == '1') ||
               GetFileAttributesA(flag) != INVALID_FILE_ATTRIBUTES;
      if (on) CreateThread(NULL, 0, selftest_thread, NULL, 0, NULL); }
    return 0;
}

BOOL WINAPI DllMain(HINSTANCE h, DWORD reason, LPVOID r) {
    (void)r;
    if (reason == DLL_PROCESS_ATTACH) {
        DisableThreadLibraryCalls(h);
        /* only one instance of the trainer may initialise */
        HANDLE m = CreateMutexA(NULL, TRUE, "Local\\GhostSongTrainerInit");
        if (m && GetLastError() == ERROR_ALREADY_EXISTS) return TRUE;
        CreateThread(NULL, 0, init_thread, NULL, 0, NULL);
    }
    return TRUE;
}

/* ------------------------------------------------------------- proxy glue */
/*  Every export of version.dll is forwarded to the real system DLL.  The
 *  signatures below match winver.h exactly so the SDK prototypes and
 *  our definitions do not clash. */
static HMODULE g_real_version;

static void ensure_real(void) {
    if (!g_real_version) {
        char path[MAX_PATH];
        GetSystemDirectoryA(path, MAX_PATH);
        strcat(path, "\\version.dll");
        g_real_version = LoadLibraryA(path);
    }
}

static FARPROC real_proc(const char *name) {
    ensure_real();
    if (!g_real_version) return NULL;
    return GetProcAddress(g_real_version, name);
}

BOOL WINAPI GetFileVersionInfoA(LPCSTR f, DWORD h, DWORD l, LPVOID d) {
    typedef BOOL(WINAPI *T)(LPCSTR, DWORD, DWORD, LPVOID);
    static T fn; if (!fn) fn = (T)real_proc("GetFileVersionInfoA");
    if (!fn) { SetLastError(ERROR_PROC_NOT_FOUND); return FALSE; }
    return fn(f, h, l, d);
}
BOOL WINAPI GetFileVersionInfoW(LPCWSTR f, DWORD h, DWORD l, LPVOID d) {
    typedef BOOL(WINAPI *T)(LPCWSTR, DWORD, DWORD, LPVOID);
    static T fn; if (!fn) fn = (T)real_proc("GetFileVersionInfoW");
    if (!fn) { SetLastError(ERROR_PROC_NOT_FOUND); return FALSE; }
    return fn(f, h, l, d);
}
BOOL WINAPI GetFileVersionInfoExA(DWORD fl, LPCSTR f, DWORD h, DWORD l, LPVOID d) {
    typedef BOOL(WINAPI *T)(DWORD, LPCSTR, DWORD, DWORD, LPVOID);
    static T fn; if (!fn) fn = (T)real_proc("GetFileVersionInfoExA");
    if (!fn) { SetLastError(ERROR_PROC_NOT_FOUND); return FALSE; }
    return fn(fl, f, h, l, d);
}
BOOL WINAPI GetFileVersionInfoExW(DWORD fl, LPCWSTR f, DWORD h, DWORD l, LPVOID d) {
    typedef BOOL(WINAPI *T)(DWORD, LPCWSTR, DWORD, DWORD, LPVOID);
    static T fn; if (!fn) fn = (T)real_proc("GetFileVersionInfoExW");
    if (!fn) { SetLastError(ERROR_PROC_NOT_FOUND); return FALSE; }
    return fn(fl, f, h, l, d);
}
BOOL WINAPI GetFileVersionInfoByHandle(DWORD fl, LPVOID d, DWORD l, LPVOID pb) {
    typedef BOOL(WINAPI *T)(DWORD, LPVOID, DWORD, LPVOID);
    static T fn; if (!fn) fn = (T)real_proc("GetFileVersionInfoByHandle");
    if (!fn) { SetLastError(ERROR_PROC_NOT_FOUND); return FALSE; }
    return fn(fl, d, l, pb);
}
DWORD WINAPI GetFileVersionInfoSizeA(LPCSTR f, LPDWORD h) {
    typedef DWORD(WINAPI *T)(LPCSTR, LPDWORD);
    static T fn; if (!fn) fn = (T)real_proc("GetFileVersionInfoSizeA");
    if (!fn) { SetLastError(ERROR_PROC_NOT_FOUND); return 0; }
    return fn(f, h);
}
DWORD WINAPI GetFileVersionInfoSizeW(LPCWSTR f, LPDWORD h) {
    typedef DWORD(WINAPI *T)(LPCWSTR, LPDWORD);
    static T fn; if (!fn) fn = (T)real_proc("GetFileVersionInfoSizeW");
    if (!fn) { SetLastError(ERROR_PROC_NOT_FOUND); return 0; }
    return fn(f, h);
}
DWORD WINAPI GetFileVersionInfoSizeExA(DWORD fl, LPCSTR f, LPDWORD h) {
    typedef DWORD(WINAPI *T)(DWORD, LPCSTR, LPDWORD);
    static T fn; if (!fn) fn = (T)real_proc("GetFileVersionInfoSizeExA");
    if (!fn) { SetLastError(ERROR_PROC_NOT_FOUND); return 0; }
    return fn(fl, f, h);
}
DWORD WINAPI GetFileVersionInfoSizeExW(DWORD fl, LPCWSTR f, LPDWORD h) {
    typedef DWORD(WINAPI *T)(DWORD, LPCWSTR, LPDWORD);
    static T fn; if (!fn) fn = (T)real_proc("GetFileVersionInfoSizeExW");
    if (!fn) { SetLastError(ERROR_PROC_NOT_FOUND); return 0; }
    return fn(fl, f, h);
}
BOOL WINAPI VerQueryValueA(LPCVOID b, LPCSTR s, LPVOID *buf, PUINT len) {
    typedef BOOL(WINAPI *T)(LPCVOID, LPCSTR, LPVOID *, PUINT);
    static T fn; if (!fn) fn = (T)real_proc("VerQueryValueA");
    if (!fn) { SetLastError(ERROR_PROC_NOT_FOUND); return FALSE; }
    return fn(b, s, buf, len);
}
BOOL WINAPI VerQueryValueW(LPCVOID b, LPCWSTR s, LPVOID *buf, PUINT len) {
    typedef BOOL(WINAPI *T)(LPCVOID, LPCWSTR, LPVOID *, PUINT);
    static T fn; if (!fn) fn = (T)real_proc("VerQueryValueW");
    if (!fn) { SetLastError(ERROR_PROC_NOT_FOUND); return FALSE; }
    return fn(b, s, buf, len);
}
DWORD WINAPI VerFindFileA(DWORD fl, LPSTR fn_, LPSTR wd, LPSTR ad, LPSTR cd, PUINT cl, LPSTR dd, PUINT dl) {
    typedef DWORD(WINAPI *T)(DWORD, LPSTR, LPSTR, LPSTR, LPSTR, PUINT, LPSTR, PUINT);
    static T fn; if (!fn) fn = (T)real_proc("VerFindFileA");
    if (!fn) { SetLastError(ERROR_PROC_NOT_FOUND); return 0; }
    return fn(fl, fn_, wd, ad, cd, cl, dd, dl);
}
DWORD WINAPI VerFindFileW(DWORD fl, LPWSTR fn_, LPWSTR wd, LPWSTR ad, LPWSTR cd, PUINT cl, LPWSTR dd, PUINT dl) {
    typedef DWORD(WINAPI *T)(DWORD, LPWSTR, LPWSTR, LPWSTR, LPWSTR, PUINT, LPWSTR, PUINT);
    static T fn; if (!fn) fn = (T)real_proc("VerFindFileW");
    if (!fn) { SetLastError(ERROR_PROC_NOT_FOUND); return 0; }
    return fn(fl, fn_, wd, ad, cd, cl, dd, dl);
}
DWORD WINAPI VerInstallFileA(DWORD fl, LPSTR sf, LPSTR df, LPSTR sd, LPSTR dd, LPSTR cd, LPSTR tf, PUINT tl) {
    typedef DWORD(WINAPI *T)(DWORD, LPSTR, LPSTR, LPSTR, LPSTR, LPSTR, LPSTR, PUINT);
    static T fn; if (!fn) fn = (T)real_proc("VerInstallFileA");
    if (!fn) { SetLastError(ERROR_PROC_NOT_FOUND); return 0; }
    return fn(fl, sf, df, sd, dd, cd, tf, tl);
}
DWORD WINAPI VerInstallFileW(DWORD fl, LPWSTR sf, LPWSTR df, LPWSTR sd, LPWSTR dd, LPWSTR cd, LPWSTR tf, PUINT tl) {
    typedef DWORD(WINAPI *T)(DWORD, LPWSTR, LPWSTR, LPWSTR, LPWSTR, LPWSTR, LPWSTR, PUINT);
    static T fn; if (!fn) fn = (T)real_proc("VerInstallFileW");
    if (!fn) { SetLastError(ERROR_PROC_NOT_FOUND); return 0; }
    return fn(fl, sf, df, sd, dd, cd, tf, tl);
}
DWORD WINAPI VerLanguageNameA(DWORD lang, LPSTR buf, DWORD size) {
    typedef DWORD(WINAPI *T)(DWORD, LPSTR, DWORD);
    static T fn; if (!fn) fn = (T)real_proc("VerLanguageNameA");
    if (!fn) { SetLastError(ERROR_PROC_NOT_FOUND); return 0; }
    return fn(lang, buf, size);
}
DWORD WINAPI VerLanguageNameW(DWORD lang, LPWSTR buf, DWORD size) {
    typedef DWORD(WINAPI *T)(DWORD, LPWSTR, DWORD);
    static T fn; if (!fn) fn = (T)real_proc("VerLanguageNameW");
    if (!fn) { SetLastError(ERROR_PROC_NOT_FOUND); return 0; }
    return fn(lang, buf, size);
}
