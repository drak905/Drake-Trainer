/*
 * Ghost Song Trainer v3 - game logic (Unity 2020.3 IL2CPP).
 *
 * Everything is resolved BY NAME through the il2cpp API.  Derivation of every rule below is in
 * artifacts/gs3/subtasks/ev_*.json (SUBAGENT-COMBAT-01, -MOVEMENT-02, -ECONOMY-03, -WORLD-04).
 *
 * Hooks (MinHook, all on the Unity main thread):
 *   status.Update / status.FixedUpdate   : tick (feature logic, one-shot requests, snapshot)
 *   playermovement.TakeDamage            : god mode (skip the call)
 *   playermovement.Jump                  : unlimited air jumps (stateless; see hk_Jump)
 *   playermovement.FixedUpdate           : marks "inside the movement step"
 *   UnityEngine.Mathf.Clamp(float x3)    : move speed (scales ONLY the player's velocity clamp)
 *   DamageCalcScript.ProcessResists      : one-hit kill
 *   themap.Show / themap.displayChunks   : show all items / chunks on the map (purely visual)
 */
#include <windows.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include "internal.h"
#include "MinHook.h"

/* ------------------------------------------------------------------ resolved metadata */
Il2CppClass *K_status, *K_charcon, *K_global, *K_pm, *K_dcs, *K_themap, *K_iteminfo, *K_mods;
static Il2CppClass *K_renderer;

typedef struct {
    /* static fields (offset inside the class static block) */
    long s_Health, s_Spirit, s_Ammo, s_GunHeat, s_Stats, s_shieldHealth, s_shieldHealthMax, s_hasShield, s_bugscraper;
    long c_isImmortal, c_isDying, c_TitleScreen, c_InSplash, c_airjumps, c_extrajumps, c_jumpPower;
    long g_statstat;
    /* instance fields */
    long i_stamina, i_staminaMax, i_suitDamage, i_flowerjuice, i_flowerjuiceMax, i_Nanites, i_PreNanites, i_BugBlood,
         i_nanotimer, i_inv, i_chunks, i_elby, i_elbypm, i_xp, i_wm, i_mm, i_sm;
    long ii_NumberOwned, ii_Stackable, ii_InternalName;
    long mo_Acquired, mo_Name;              /* Mods struct (inline array elements) */
    long pm_rightwj, pm_leftwj;
    long tm_chunkRenderers, tm_saveIcons, tm_bbIcons;
} Meta;
static Meta M;

static const Il2CppMethod *MI_rest, *MI_flip, *MI_gainitem, *MI_gainmodule, *MI_setenabled;
static char *SB_status, *SB_charcon, *SB_global;       /* cached static blocks */
static int  g_sb_validated, g_sb_valid;

#define SBP(sb, off, T) (*(T *)((sb) + (off)))
#define IFP(obj, off, T) (*(T *)((char *)(obj) + (off)))

int g_hs_tick, g_hs_jump, g_hs_clamp, g_hs_ohk, g_hs_map, g_hs_dmg, g_hs_rest, g_hs_mapfn;
volatile LONG g_cnt_dmg_blocked, g_cnt_ohk_calls, g_cnt_ohk_boost, g_cnt_clamp_calls, g_cnt_clamp_scaled,
              g_cnt_jump_calls, g_cnt_jump_assist, g_cnt_map_show, g_cnt_ticks, g_cnt_fixed;

static void *g_clamp_site;          /* return address of the player's velocity clamp (NULL = heuristic) */
static volatile int g_in_pm_fixed;  /* set while playermovement.FixedUpdate runs                        */
static void *g_status_obj;          /* last `status` seen by the tick hook                               */
static Gs3Snapshot g_snap;

/* ------------------------------------------------------------------ small helpers */
static long field_off(Il2CppClass *k, const char *name, int quiet)
{
    if (!k) return -1;
    Il2CppField *f = il2cpp_class_get_field_from_name(k, name);
    if (!f) { if (!quiet) gs3_log("  MISSING field %s.%s", il2cpp_class_get_name(k), name); return -1; }
    return (long)il2cpp_field_get_offset(f);
}

static int g_meta_missing;
static long need(Il2CppClass *k, const char *name)
{
    long o = field_off(k, name, 0);
    if (o < 0) g_meta_missing++;
    return o;
}

/* UTF-16 managed string -> ASCII (only for diagnostics) */
static void str_ascii(void *s, char *out, size_t cap)
{
    out[0] = 0;
    if (!s || cap < 2) return;
    int len = *(int *)((char *)s + 0x10);
    const unsigned short *c = (const unsigned short *)((char *)s + 0x14);
    if (len < 0 || len > 200) len = 0;
    size_t j = 0;
    for (int i = 0; i < len && j + 1 < cap; i++) out[j++] = (c[i] < 0x80) ? (char)c[i] : '?';
    out[j] = 0;
}

/* ------------------------------------------------------------------ game state accessors */
void *game_status(void)
{
    if (!SB_global || !M.g_statstat) return NULL;
    return SBP(SB_global, M.g_statstat, void *);
}

int game_in_gameplay(void *st)
{
    if (!st || !g_sb_valid) return 0;
    if (SBP(SB_charcon, M.c_TitleScreen, uint8_t) || SBP(SB_charcon, M.c_InSplash, uint8_t)) return 0;
    return IFP(st, M.i_elby, void *) != NULL && IFP(st, M.i_elbypm, void *) != NULL;
}

int   game_nanites(void *st)            { return IFP(st, M.i_Nanites, int); }
void  game_set_nanites(void *st, int v) { IFP(st, M.i_Nanites, int) = v; }
float game_health(void)                 { return SBP(SB_status, M.s_Health, float); }
void  game_set_health(float v)          { SBP(SB_status, M.s_Health, float) = v; }
float game_health_max(void)             { return SBP(SB_status, M.s_Stats, float); }          /* Stats.Health = +0 */
float game_stamina(void *st)            { return IFP(st, M.i_stamina, float); }
void  game_set_stamina(void *st, float v) { IFP(st, M.i_stamina, float) = v; }
float game_stamina_max(void *st)        { return IFP(st, M.i_staminaMax, float); }
float game_get_ammo(void)               { return SBP(SB_status, M.s_Ammo, float); }
void  game_set_ammo(float v)            { SBP(SB_status, M.s_Ammo, float) = v; }
float game_ammo_max(void)               { return *(float *)(SB_status + M.s_Stats + 8); }       /* Stats.Ammo = +8 */

int game_item_count(void *st)
{
    void *arr = IFP(st, M.i_inv, void *);
    return arr ? (int)IL2_ARR_LEN(arr) : 0;
}

static void *item_obj(void *st, int idx)
{
    void *arr = IFP(st, M.i_inv, void *);
    if (!arr || idx < 0 || (uint32_t)idx >= IL2_ARR_LEN(arr)) return NULL;
    return IL2_ARR_ELEM(arr, idx);
}

int game_item_owned(void *st, int idx)
{
    void *it = item_obj(st, idx);
    return it ? IFP(it, M.ii_NumberOwned, int) : 0;
}

void game_set_item_owned(void *st, int idx, int v)
{
    void *it = item_obj(st, idx);
    if (it) IFP(it, M.ii_NumberOwned, int) = v;
}

int game_do_add_money(int amount)
{
    void *st = game_status();
    if (!st) return 0;
    long long v = (long long)game_nanites(st) + amount;
    if (v > 2000000000LL) v = 2000000000LL;
    if (v < 0) v = 0;
    game_set_nanites(st, (int)v);
    IFP(st, M.i_nanotimer, int) = 400;          /* make the HUD nano counter slide in */
    return (int)v;
}

int game_map_info(int *chunkRenderers, int *chunksOwned)
{
    void *st = game_status();
    if (!st) return 0;
    void *co = IFP(st, M.i_chunks, void *);
    *chunksOwned = co ? (int)IL2_ARR_LEN(co) : 0;
    *chunkRenderers = 0;
    return 1;
}

/* ------------------------------------------------------------------ invoking game methods (game thread only) */
static int invoke(const Il2CppMethod *m, void *obj, void **args)
{
    if (!m) return 0;
    Il2CppObject *exc = NULL;
    il2cpp_runtime_invoke(m, obj, args, &exc);
    if (exc) { gs3_log("invoke %s threw an exception", il2cpp_method_get_name(m)); return 0; }
    return 1;
}

static void set_renderer_enabled(void *rend, int on)
{
    if (!rend || !MI_setenabled) return;
    uint8_t b = on ? 1 : 0;
    void *args[1] = { &b };
    invoke(MI_setenabled, rend, args);
}

static void enable_all_in(void *arr)
{
    if (!arr) return;
    uint32_t n = IL2_ARR_LEN(arr);
    if (n > 4096) return;
    for (uint32_t i = 0; i < n; i++) set_renderer_enabled(IL2_ARR_ELEM(arr, i), 1);
}

/* ------------------------------------------------------------------ detours */
typedef void  (*fn_void_this)(void *self, const void *mi);
typedef void  (*fn_TakeDamage)(void *self, float, float, float, float, float, float, void *, void *, uint8_t, void *, const void *);
typedef float (*fn_Clamp)(float v, float lo, float hi, const void *mi);
typedef float (*fn_Resists)(void *self, void *rs, void *bd, const void *mi);
typedef void  (*fn_Show)(void *self, uint8_t show, const void *mi);

static fn_void_this  o_status_Update, o_status_FixedUpdate, o_pm_Jump, o_pm_FixedUpdate, o_map_display;
static fn_TakeDamage o_TakeDamage;
static fn_Clamp      o_Clamp;
static fn_Resists    o_Resists;
static fn_Show       o_Show;

static void tick(void *st, int is_fixed);

static void hk_status_Update(void *self, const void *mi)
{
    o_status_Update(self, mi);
    g_status_obj = self;
    InterlockedIncrement(&g_cnt_ticks);
    tick(self, 0);
}

static void hk_status_FixedUpdate(void *self, const void *mi)
{
    o_status_FixedUpdate(self, mi);
    InterlockedIncrement(&g_cnt_fixed);
    tick(self, 1);                       /* runs AFTER the game's own clamps / derived stats */
}

/* GOD MODE: playermovement exists only for the player, and TakeDamage is the choke point of all enemy / hazard damage. */
static void hk_TakeDamage(void *self, float a, float b, float c, float d, float e, float f, void *s1, void *s2, uint8_t ov, void *atk, const void *mi)
{
    if (g_ft[FT_GOD]) { InterlockedIncrement(&g_cnt_dmg_blocked); return; }
    o_TakeDamage(self, a, b, c, d, e, f, s1, s2, ov, atk, mi);
}

/*
 * UNLIMITED JUMP.  Jump() allows a mid-air jump iff
 *     charcon.airjumps < items[0].NumberOwned + charcon.extrajumps + items[53].NumberOwned
 * and Airjump() does airjumps++.  We make the cap >= 1 and clear the counter only for the duration of this call
 * (extrajumps is restored afterwards), so nothing is left behind when the toggle is switched off.
 */
static void hk_Jump(void *self, const void *mi)
{
    if (g_ft[FT_JUMP] && g_sb_valid) {
        InterlockedIncrement(&g_cnt_jump_calls);
        int *extra = &SBP(SB_charcon, M.c_extrajumps, int);
        int *aj    = &SBP(SB_charcon, M.c_airjumps, int);
        int saved = *extra;
        void *st = game_status();
        int cap = saved;
        if (st) cap += game_item_owned(st, 0) + game_item_owned(st, 53);
        if (cap < 1) { *extra = saved + (1 - cap); InterlockedIncrement(&g_cnt_jump_assist); }
        *aj = 0;
        o_pm_Jump(self, mi);
        *extra = saved;
        return;
    }
    o_pm_Jump(self, mi);
}

static void hk_pm_FixedUpdate(void *self, const void *mi)
{
    g_in_pm_fixed = 1;
    o_pm_FixedUpdate(self, mi);
    g_in_pm_fixed = 0;
}

/*
 * MOVE SPEED.  Run speed is NOT limited by jogSpeed (that only scales the AddForce): the final limit is
 * rb.velocity.x = Mathf.Clamp(vx, -spedd, +spedd) with spedd lerped toward hard-coded 5.8 / 7.5 / 8.5.
 * We scale the bounds of exactly that one Clamp call (identified by its return address, or - if the call-site could
 * not be pinned down - by "inside playermovement.FixedUpdate and symmetric bounds beyond +-2").
 */
static float hk_Clamp(float v, float lo, float hi, const void *mi)
{
    if (g_ft[FT_SPEED]) {
        InterlockedIncrement(&g_cnt_clamp_calls);
        int hit;
        if (g_clamp_site) hit = (__builtin_return_address(0) == g_clamp_site);
        else              hit = (g_in_pm_fixed && lo <= -2.0f && hi >= 2.0f);
        if (hit && g_sb_valid) {
            void *st = g_status_obj ? g_status_obj : game_status();
            void *pm = st ? IFP(st, M.i_elbypm, void *) : NULL;
            /* wall-jump kick forces the bounds to +-15: do not multiply it */
            if (pm && IFP(pm, M.pm_rightwj, int) <= 0 && IFP(pm, M.pm_leftwj, int) <= 0) {
                float k = g_set.speed_mult;
                lo *= k; hi *= k;
                InterlockedIncrement(&g_cnt_clamp_scaled);
            }
        }
    }
    return o_Clamp(v, lo, hi, mi);
}

/* ONE-HIT KILL.  ProcessResists() turns one queued hit into the number subtracted from the ENEMY's DamageCalcScript.Health
 * (0 for immune parts / resisted damage types) - promote every hit that would have hurt. */
static float hk_Resists(void *self, void *rs, void *bd, const void *mi)
{
    float r = o_Resists(self, rs, bd, mi);
    if (g_ft[FT_OHK]) {
        InterlockedIncrement(&g_cnt_ohk_calls);
        if (r > 0.0f) { InterlockedIncrement(&g_cnt_ohk_boost); r = 1.0e6f; }
    }
    return r;
}

/* MAP.  Purely visual (nothing is written to the save): after the game laid out the map, force-enable every chunk sprite,
 * every per-room "single" (pickup) icon group and the save / big-bot icons. */
static void map_show_chunks(void *tm)
{
    enable_all_in(IFP(tm, M.tm_chunkRenderers, void *));
}

static void map_show_icons(void *tm)
{
    if (MI_flip) { uint8_t t = 1; void *args[1] = { &t }; invoke(MI_flip, tm, args); }
    enable_all_in(IFP(tm, M.tm_saveIcons, void *));
    enable_all_in(IFP(tm, M.tm_bbIcons, void *));
}

static void hk_map_display(void *self, const void *mi)
{
    o_map_display(self, mi);
    if (g_ft[FT_MAPALL]) map_show_chunks(self);
}

static void hk_Show(void *self, uint8_t show, const void *mi)
{
    o_Show(self, show, mi);
    InterlockedIncrement(&g_cnt_map_show);
    if (show && g_ft[FT_MAPALL]) { map_show_chunks(self); map_show_icons(self); }
}

/* ------------------------------------------------------------------ feature logic (game thread) */
static const struct { int idx, floor; } TIER_A[] = {         /* consumables that are used up during normal play */
    { 21, 25 }, { 36, 5 }, { 39, 25 }, { 40, 25 }, { 41, 25 }, { 64, 25 }, { 65, 25 }, { 66, 25 } };
static const int TIER_B[]    = { 14, 15, 16, 31, 57, 58, 60, 61, 62 };   /* permanent-stat fruit / seeds (saved stats!) */
static const int GIVE_ITEMS[] = { 0, 4, 9, 19, 20, 37, 53, 1, 11, 12, 26, 32, 33, 34, 35, 68, 29 };
static const int GIVE_WEAPON[] = { 0, 1, 2, 3, 4, 5, 7, 9, 11, 12, 13, 14, 15 };

static int g_god_active, g_god_prev;

static void apply_features(void *st)
{
    char *S = SB_status, *C = SB_charcon;
    int dying = SBP(C, M.c_isDying, uint8_t) != 0;
    float hpmax = *(float *)(S + M.s_Stats + 0);

    /* ---- god mode: no damage (hook) + cannot die (isImmortal) + health pinned to max ---- */
    if (g_ft[FT_GOD]) {
        if (!g_god_active) { g_god_prev = SBP(C, M.c_isImmortal, uint8_t); g_god_active = 1; }
        SBP(C, M.c_isImmortal, uint8_t) = 1;
        if (!dying) {
            if (SBP(S, M.s_Health, float) < hpmax) SBP(S, M.s_Health, float) = hpmax;
            if (SBP(S, M.s_hasShield, int) > 0 && SBP(S, M.s_shieldHealth, int) < SBP(S, M.s_shieldHealthMax, int))
                SBP(S, M.s_shieldHealth, int) = SBP(S, M.s_shieldHealthMax, int);
        }
    } else if (g_god_active) {
        if (!dying && SBP(S, M.s_Health, float) < hpmax) SBP(S, M.s_Health, float) = hpmax;   /* never leave with 0 hp */
        SBP(C, M.c_isImmortal, uint8_t) = (uint8_t)g_god_prev;
        g_god_active = 0;
    }

    /* ---- infinite stamina + spirit (spirit = mana, NOT the currency) ---- */
    if (g_ft[FT_STAMINA] && !dying) {
        float sm = IFP(st, M.i_staminaMax, float);
        if (sm > 0.0f && IFP(st, M.i_stamina, float) < sm) IFP(st, M.i_stamina, float) = sm;
        float spm = *(float *)(S + M.s_Stats + 4);
        if (spm > 0.0f && SBP(S, M.s_Spirit, float) < spm) SBP(S, M.s_Spirit, float) = spm;
    }

    /* ---- infinite ammo / no overheat ---- */
    if (g_ft[FT_AMMO] || g_ft[FT_ITEMS]) {
        float am = *(float *)(S + M.s_Stats + 8);
        if (am > 0.0f && SBP(S, M.s_Ammo, float) < am) SBP(S, M.s_Ammo, float) = am;
    }
    if (g_ft[FT_AMMO] && SBP(S, M.s_GunHeat, float) > 0.0f) SBP(S, M.s_GunHeat, float) = 0.0f;

    /* ---- unlimited money: Nanites is the shop currency; spend sites are inlined everywhere, so top it up ---- */
    if (g_ft[FT_MONEY]) {
        int target = g_set.money_target;
        float rq = IFP(st, M.i_xp, float);                  /* level-up cost must stay affordable */
        if (rq > 0.0f && rq < 1.9e9f && (int)rq + 1 > target) target = (int)rq + 1;
        if (IFP(st, M.i_Nanites, int) < target) IFP(st, M.i_Nanites, int) = target;
        if (IFP(st, M.i_BugBlood, int) > 0 || SBP(S, M.s_bugscraper, int) > 0) {
            if (IFP(st, M.i_BugBlood, int) < 999999) IFP(st, M.i_BugBlood, int) = 999999;
        }
    }

    /* ---- unlimited items: keep the consumables stocked, heal fuel full ---- */
    if (g_ft[FT_ITEMS]) {
        for (size_t i = 0; i < sizeof TIER_A / sizeof TIER_A[0]; i++) {
            void *it = item_obj(st, TIER_A[i].idx);
            if (it && IFP(it, M.ii_NumberOwned, int) < TIER_A[i].floor) IFP(it, M.ii_NumberOwned, int) = TIER_A[i].floor;
        }
        if (game_item_owned(st, 7) > 0) {                  /* healing cores: refill the fuel (10 per heal) */
            float fm = IFP(st, M.i_flowerjuiceMax, float);
            if (IFP(st, M.i_flowerjuice, float) < fm) IFP(st, M.i_flowerjuice, float) = fm;
        }
        if (g_ft[FT_SEEDS]) {
            for (size_t i = 0; i < sizeof TIER_B / sizeof TIER_B[0]; i++) {
                void *it = item_obj(st, TIER_B[i]);
                if (it && IFP(it, M.ii_NumberOwned, int) < 25) IFP(it, M.ii_NumberOwned, int) = 25;
            }
        }
    }
}

void game_apply_all(void *st) { apply_features(st); }

/* ---- give-all queue (one official GainItem / GainModule call every few frames: they raise pop-ups and may save) ---- */
typedef struct { uint8_t kind, sub; int idx; } GiveOp;      /* kind 0 = GainItem(idx), 1 = GainModule(idx, sub, true) */
static GiveOp g_gq[200];
static int g_gq_n, g_gq_pos, g_gq_wait;

int gs3_giveall_busy(void) { return g_gq_pos < g_gq_n; }

static void gq_add(int kind, int sub, int idx)
{
    if (g_gq_n < (int)(sizeof g_gq / sizeof g_gq[0])) { g_gq[g_gq_n].kind = (uint8_t)kind; g_gq[g_gq_n].sub = (uint8_t)sub; g_gq[g_gq_n].idx = idx; g_gq_n++; }
}

static int module_acquired(void *st, long fieldoff, int n)
{
    void *arr = IFP(st, fieldoff, void *);
    if (!arr || n < 0 || (uint32_t)n >= IL2_ARR_LEN(arr)) return -1;           /* -1 = does not exist */
    long adj = (M.mo_Name == 0x10) ? 0x10 : 0;                                 /* struct fields carry the object header in metadata */
    return *((uint8_t *)arr + 0x20 + 16 * (long)n + (M.mo_Acquired - adj)) != 0;
}

static void giveall_begin(void *st)
{
    g_gq_n = g_gq_pos = g_gq_wait = 0;
    for (size_t i = 0; i < sizeof GIVE_ITEMS / sizeof GIVE_ITEMS[0]; i++) {
        int idx = GIVE_ITEMS[i];
        if (item_obj(st, idx) && game_item_owned(st, idx) <= 0) gq_add(0, 0, idx);   /* GainItem redirects duplicates to junk: skip owned */
    }
    for (int c = game_item_owned(st, 7); c < 10; c++) gq_add(0, 0, 7);                /* healing cores, game cap = 10 */
    for (size_t i = 0; i < sizeof GIVE_WEAPON / sizeof GIVE_WEAPON[0]; i++)
        if (module_acquired(st, M.i_wm, GIVE_WEAPON[i]) == 0) gq_add(1, 0, GIVE_WEAPON[i]);
    for (int n = 0; n <= 17; n++) if (module_acquired(st, M.i_mm, n) == 0) gq_add(1, 1, n);
    for (int n = 0; n <= 8; n++)  if (module_acquired(st, M.i_sm, n) == 0) gq_add(1, 2, n);
    gs3_toast("Giving %d items / modules ...", g_gq_n);
}

static void giveall_step(void *st)
{
    if (g_gq_pos >= g_gq_n) return;
    if (g_gq_wait > 0) { g_gq_wait--; return; }
    GiveOp op = g_gq[g_gq_pos++];
    if (op.kind == 0) {
        int idx = op.idx; void *args[1] = { &idx };
        invoke(MI_gainitem, st, args);
    } else {
        static const char *const kinds[3] = { "weapon", "mod", "special" };
        int n = op.idx; uint8_t bypass = 1;
        void *args[3] = { &n, il2cpp_string_new(kinds[op.sub % 3]), &bypass };
        invoke(MI_gainmodule, st, args);
    }
    g_gq_wait = 8;
    if (g_gq_pos >= g_gq_n) gs3_toast("Give all items: done (%d calls)", g_gq_n);
}

static void service_requests(void *st)
{
    if (InterlockedExchange(&g_req[AC_ADDMONEY], 0) > 0) {
        int v = game_do_add_money(g_set.money_amount);
        gs3_toast("+%d Nanogel  (now %d)", g_set.money_amount, v);
    }
    if (InterlockedExchange(&g_req[AC_HEAL], 0) > 0) {
        if (SBP(SB_charcon, M.c_isDying, uint8_t)) gs3_toast("Cannot heal while dying");
        else if (invoke(MI_rest, st, NULL)) gs3_toast("Healed (official status.rest)");
    }
    if (InterlockedExchange(&g_req[AC_GIVEALL], 0) > 0) giveall_begin(st);
    if (InterlockedExchange(&g_req[AC_UNLOCKMAP], 0) > 0) {
        void *co = IFP(st, M.i_chunks, void *);
        if (co) {
            uint32_t n = IL2_ARR_LEN(co);
            for (uint32_t i = 0; i < n && i < 4096; i++) *(int *)((char *)co + 0x20 + 4 * i) = 1;
            gs3_toast("Map: %u chunks unlocked (saved)", n);
        }
    }
    if (InterlockedExchange(&g_req[AC_DIAG], 0) > 0) { game_diag(); gs3_toast("Diagnostics written to gs3_trainer.log"); }
}

static void publish_snapshot(void *st)
{
    char *S = SB_status;
    Gs3Snapshot s;
    s.valid = 1;
    s.hp = SBP(S, M.s_Health, float);          s.hpmax = *(float *)(S + M.s_Stats + 0);
    s.spirit = SBP(S, M.s_Spirit, float);      s.spiritmax = *(float *)(S + M.s_Stats + 4);
    s.stamina = IFP(st, M.i_stamina, float);   s.staminamax = IFP(st, M.i_staminaMax, float);
    s.ammo = SBP(S, M.s_Ammo, float);          s.ammomax = *(float *)(S + M.s_Stats + 8);
    s.nanites = IFP(st, M.i_Nanites, int);     s.blood = IFP(st, M.i_BugBlood, int);
    s.heals = game_item_owned(st, 7);
    s.map_site_ok = g_clamp_site != NULL;
    g_snap = s;
}

void gs3_get_snapshot(Gs3Snapshot *out) { *out = g_snap; }

static int validate_statics(void)
{
    if (g_sb_validated) return g_sb_valid;
    SB_status = il2_static_base(K_status);
    SB_charcon = il2_static_base(K_charcon);
    SB_global = il2_static_base(K_global);
    if (!SB_status || !SB_charcon || !SB_global) return 0;          /* class constructors not run yet */
    /* the static block offset (Il2CppClass+0xB8) is an assumption: cross-check against the official API */
    Il2CppField *f = il2cpp_class_get_field_from_name(K_charcon, "jumpPower");
    float api = 0.0f;
    if (f) il2cpp_field_static_get_value(f, &api);
    float direct = SBP(SB_charcon, M.c_jumpPower, float);
    g_sb_valid = (f != NULL && api == direct && api > 100.0f && api < 100000.0f);
    g_sb_validated = 1;
    gs3_log("static block check: charcon.jumpPower api=%.1f direct=%.1f -> %s", (double)api, (double)direct, g_sb_valid ? "OK" : "MISMATCH (features disabled)");
    if (!g_sb_valid) { g_hs_tick = HS_FAIL; }
    return g_sb_valid;
}

static void tick(void *st_this, int is_fixed)
{
    if (!validate_statics()) return;
    void *st = game_status();
    if (!st) st = st_this;
    if (!game_in_gameplay(st)) { if (!is_fixed) g_snap.valid = 0; return; }
    if (!is_fixed) {
        service_requests(st);
        giveall_step(st);
        selftest_step(st);
        publish_snapshot(st);
    }
    apply_features(st);
}

/* ------------------------------------------------------------------ diagnostics */
void game_diag(void)
{
    void *st = game_status();
    gs3_log("---- diagnostics ----");
    gs3_log("hooks: tick=%d dmg=%d jump=%d clamp=%d ohk=%d map=%d rest=%d clampSite=%p", g_hs_tick, g_hs_dmg, g_hs_jump, g_hs_clamp, g_hs_ohk, g_hs_map, g_hs_rest, g_clamp_site);
    gs3_log("counters: ticks=%ld fixed=%ld dmgBlocked=%ld jumpCalls=%ld jumpAssist=%ld clampCalls=%ld clampScaled=%ld ohkCalls=%ld ohkBoost=%ld mapShow=%ld",
            g_cnt_ticks, g_cnt_fixed, g_cnt_dmg_blocked, g_cnt_jump_calls, g_cnt_jump_assist, g_cnt_clamp_calls, g_cnt_clamp_scaled, g_cnt_ohk_calls, g_cnt_ohk_boost, g_cnt_map_show);
    if (!st || !g_sb_valid) { gs3_log("no running game state"); return; }
    gs3_log("hp %.0f/%.0f spirit %.0f/%.0f stamina %.0f/%.0f ammo %.0f/%.0f nanites %d (pre %d) blood %d heat %.1f",
            (double)game_health(), (double)game_health_max(), (double)SBP(SB_status, M.s_Spirit, float), (double)*(float *)(SB_status + M.s_Stats + 4),
            (double)game_stamina(st), (double)game_stamina_max(st), (double)game_get_ammo(), (double)game_ammo_max(),
            game_nanites(st), IFP(st, M.i_PreNanites, int), IFP(st, M.i_BugBlood, int), (double)SBP(SB_status, M.s_GunHeat, float));
    gs3_log("charcon: immortal=%d dying=%d airjumps=%d extrajumps=%d",
            SBP(SB_charcon, M.c_isImmortal, uint8_t), SBP(SB_charcon, M.c_isDying, uint8_t), SBP(SB_charcon, M.c_airjumps, int), SBP(SB_charcon, M.c_extrajumps, int));
    int n = game_item_count(st);
    gs3_log("inventoryItems: %d entries", n);
    for (int i = 0; i < n; i++) {
        void *it = item_obj(st, i);
        if (!it) continue;
        char nm[64]; str_ascii(IFP(it, M.ii_InternalName, void *), nm, sizeof nm);
        gs3_log("  [%2d] %-18s owned=%d stackable=%d", i, nm, IFP(it, M.ii_NumberOwned, int), IFP(it, M.ii_Stackable, uint8_t));
    }
    void *co = IFP(st, M.i_chunks, void *);
    int owned = 0;
    if (co) for (uint32_t i = 0; i < IL2_ARR_LEN(co); i++) owned += *(int *)((char *)co + 0x20 + 4 * i) == 1;
    gs3_log("map chunks owned %d / %d", owned, co ? (int)IL2_ARR_LEN(co) : 0);
    void *tm = NULL;
    if (K_themap) {
        Il2CppField *f = il2cpp_class_get_field_from_name(K_status, "MapScript");
        if (f) tm = IFP(st, (long)il2cpp_field_get_offset(f), void *);
    }
    if (tm) {
        void *cr = IFP(tm, M.tm_chunkRenderers, void *), *si = IFP(tm, M.tm_saveIcons, void *), *bi = IFP(tm, M.tm_bbIcons, void *);
        gs3_log("themap: chunkRenderers=%d saveIcons=%d bbIcons=%d", cr ? (int)IL2_ARR_LEN(cr) : -1, si ? (int)IL2_ARR_LEN(si) : -1, bi ? (int)IL2_ARR_LEN(bi) : -1);
    }
    gs3_log("---------------------");
}

/* ------------------------------------------------------------------ resolution + hook installation (init thread) */
static uintptr_t g_ga_base;

static int install(const char *label, const Il2CppMethod *m, void *detour, void **orig)
{
    void *p = il2_method_ptr(m);
    if (!p) { gs3_log("hook %-36s : method not found", label); return 0; }
    MH_STATUS s = MH_CreateHook(p, detour, orig);
    if (s != MH_OK) { gs3_log("hook %-36s : MH_CreateHook %s", label, MH_StatusToString(s)); return 0; }
    s = MH_EnableHook(p);
    if (s != MH_OK) { gs3_log("hook %-36s : MH_EnableHook %s", label, MH_StatusToString(s)); return 0; }
    gs3_log("hook %-36s : OK  @%p  (GameAssembly+0x%llX)", label, p, (unsigned long long)((uintptr_t)p - g_ga_base));
    return 1;
}

static const Il2CppMethod *find_clamp_float(Il2CppClass *mathf)
{
    void *it = NULL;
    Il2CppMethod *m;
    while ((m = il2cpp_class_get_methods(mathf, &it)) != NULL) {
        const char *n = il2cpp_method_get_name(m);
        if (!n || strcmp(n, "Clamp") != 0 || il2cpp_method_get_param_count(m) != 3) continue;
        const Il2CppType *t0 = il2cpp_method_get_param(m, 0), *t1 = il2cpp_method_get_param(m, 1), *t2 = il2cpp_method_get_param(m, 2);
        if (t0 && t1 && t2 && il2cpp_type_get_type(t0) == IL2T_R4 && il2cpp_type_get_type(t1) == IL2T_R4 && il2cpp_type_get_type(t2) == IL2T_R4) return m;
    }
    return NULL;
}

/* The player's velocity clamp is the 3rd (last) Mathf.Clamp(float) call of playermovement.FixedUpdate. */
static void *find_clamp_site(const uint8_t *fu, const uint8_t *clamp)
{
    if (!fu || !clamp) return NULL;
    const size_t kExactOff = 0x3654;                           /* reference build 1.2.12b: GameAssembly+0x248254 - FixedUpdate(0x244C00) */
    if (fu[kExactOff] == 0xE8 && fu + kExactOff + 5 + *(const int32_t *)(fu + kExactOff + 1) == clamp) return (void *)(fu + kExactOff + 5);
    int cnt = 0; const uint8_t *last = NULL;
    for (size_t i = 0; i + 5 < 0x4220; i++)
        if (fu[i] == 0xE8 && fu + i + 5 + *(const int32_t *)(fu + i + 1) == clamp) { cnt++; last = fu + i + 5; }
    return cnt == 3 ? (void *)last : NULL;
}

static int resolve_metadata(void)
{
    K_status = il2_find_class("", "status");
    K_charcon = il2_find_class("", "charcon");
    K_global = il2_find_class("", "global");
    K_pm = il2_find_class("", "playermovement");
    K_dcs = il2_find_class("", "DamageCalcScript");
    K_themap = il2_find_class("", "themap");
    K_iteminfo = il2_find_class("", "ItemInfo");
    K_mods = il2_find_class("", "Mods");
    K_renderer = il2_find_class_in("UnityEngine.CoreModule", "UnityEngine", "Renderer");
    if (!K_status || !K_charcon || !K_global || !K_pm || !K_iteminfo) {
        gs3_log("core classes missing (status=%p charcon=%p global=%p playermovement=%p ItemInfo=%p)", K_status, K_charcon, K_global, K_pm, K_iteminfo);
        return 1;
    }
    g_meta_missing = 0;
    M.s_Health = need(K_status, "Health");       M.s_Spirit = need(K_status, "Spirit");     M.s_Ammo = need(K_status, "Ammo");
    M.s_GunHeat = need(K_status, "GunHeat");     M.s_Stats = need(K_status, "Stats");
    M.s_shieldHealth = need(K_status, "shieldHealth"); M.s_shieldHealthMax = need(K_status, "shieldHealthMax");
    M.s_hasShield = need(K_status, "hasShield"); M.s_bugscraper = need(K_status, "bugscraper");
    M.c_isImmortal = need(K_charcon, "isImmortal"); M.c_isDying = need(K_charcon, "isDying");
    M.c_TitleScreen = need(K_charcon, "TitleScreen"); M.c_InSplash = need(K_charcon, "InSplashSequence");
    M.c_airjumps = need(K_charcon, "airjumps"); M.c_extrajumps = need(K_charcon, "extrajumps"); M.c_jumpPower = need(K_charcon, "jumpPower");
    M.g_statstat = need(K_global, "statstat");
    M.i_stamina = need(K_status, "stamina");     M.i_staminaMax = need(K_status, "staminaMax");
    M.i_suitDamage = need(K_status, "suitDamage");
    M.i_flowerjuice = need(K_status, "flowerjuice"); M.i_flowerjuiceMax = need(K_status, "flowerjuiceMax");
    M.i_Nanites = need(K_status, "Nanites");     M.i_PreNanites = need(K_status, "PreNanites"); M.i_BugBlood = need(K_status, "BugBlood");
    M.i_nanotimer = need(K_status, "nanotimer"); M.i_inv = need(K_status, "inventoryItems"); M.i_chunks = need(K_status, "mapChunksOwned");
    M.i_elby = need(K_status, "elby");           M.i_elbypm = need(K_status, "elbypm");     M.i_xp = need(K_status, "xp");
    M.i_wm = need(K_status, "weaponmodules");    M.i_mm = need(K_status, "modmodules");     M.i_sm = need(K_status, "specialmodules");
    M.ii_NumberOwned = need(K_iteminfo, "NumberOwned"); M.ii_Stackable = need(K_iteminfo, "Stackable"); M.ii_InternalName = need(K_iteminfo, "InternalName");
    M.pm_rightwj = need(K_pm, "rightwj");        M.pm_leftwj = need(K_pm, "leftwj");
    if (K_mods) { M.mo_Name = need(K_mods, "Name"); M.mo_Acquired = need(K_mods, "Acquired"); } else g_meta_missing++;
    if (K_themap) {
        M.tm_chunkRenderers = field_off(K_themap, "chunkRenderers", 0);
        M.tm_saveIcons = field_off(K_themap, "save_icons", 0);
        M.tm_bbIcons = field_off(K_themap, "bb_icons", 0);
    }
    if (g_meta_missing) { gs3_log("metadata: %d required fields missing -> core features disabled", g_meta_missing); return 2; }

    MI_rest = il2_find_method(K_status, "rest", 0);
    MI_gainitem = il2_find_method(K_status, "GainItem", 1);
    MI_gainmodule = il2_find_method(K_status, "GainModule", 3);
    MI_flip = il2_find_method(K_themap, "FlipAllSingles", 1);
    MI_setenabled = il2_find_method(K_renderer, "set_enabled", 1);
    g_hs_rest = (MI_rest && MI_gainitem && MI_gainmodule) ? HS_OK : HS_FAIL;
    gs3_log("metadata OK: status.Nanites@0x%lX inventoryItems@0x%lX ItemInfo.NumberOwned@0x%lX Mods.Acquired@0x%lX; rest=%p GainItem=%p GainModule=%p FlipAllSingles=%p Renderer.set_enabled=%p",
            M.i_Nanites, M.i_inv, M.ii_NumberOwned, M.mo_Acquired, (void *)MI_rest, (void *)MI_gainitem, (void *)MI_gainmodule, (void *)MI_flip, (void *)MI_setenabled);
    return 0;
}

int game_init(void)
{
    for (int i = 0; i < 900 && !GetModuleHandleA("GameAssembly.dll"); i++) Sleep(200);
    g_ga_base = (uintptr_t)GetModuleHandleA("GameAssembly.dll");
    if (!g_ga_base) { gs3_log("GameAssembly.dll not found - not an il2cpp game?"); g_hs_tick = HS_FAIL; return 1; }
    if (il2_bind()) { gs3_log("il2cpp API not exported by GameAssembly.dll"); g_hs_tick = HS_FAIL; return 2; }

    DWORD t0 = GetTickCount();
    for (;;) {                                           /* wait until the runtime has loaded Assembly-CSharp */
        if (il2cpp_domain_get() && il2_find_class("", "status")) break;
        if (GetTickCount() - t0 > 240000) { gs3_log("timeout waiting for the il2cpp runtime"); g_hs_tick = HS_FAIL; return 3; }
        Sleep(250);
    }
    Sleep(1000);
    il2cpp_thread_attach(il2cpp_domain_get());
    gs3_log("il2cpp runtime ready (GameAssembly @ %p)", (void *)g_ga_base);

    if (resolve_metadata()) { g_hs_tick = HS_FAIL; return 4; }

    /* ---- hooks ---- */
    int ok_tick = install("status.Update", il2_find_method(K_status, "Update", 0), (void *)hk_status_Update, (void **)&o_status_Update)
               && install("status.FixedUpdate", il2_find_method(K_status, "FixedUpdate", 0), (void *)hk_status_FixedUpdate, (void **)&o_status_FixedUpdate);
    if (!ok_tick) { g_hs_tick = HS_FAIL; return 5; }

    g_hs_dmg = install("playermovement.TakeDamage", il2_find_method(K_pm, "TakeDamage", 10), (void *)hk_TakeDamage, (void **)&o_TakeDamage) ? HS_OK : HS_FAIL;
    g_hs_jump = install("playermovement.Jump", il2_find_method(K_pm, "Jump", 0), (void *)hk_Jump, (void **)&o_pm_Jump) ? HS_OK : HS_FAIL;

    const Il2CppMethod *mfu = il2_find_method(K_pm, "FixedUpdate", 0);
    int fu_ok = install("playermovement.FixedUpdate", mfu, (void *)hk_pm_FixedUpdate, (void **)&o_pm_FixedUpdate);
    Il2CppClass *mathf = il2_find_class_in("UnityEngine.CoreModule", "UnityEngine", "Mathf");
    const Il2CppMethod *mclamp = mathf ? find_clamp_float(mathf) : NULL;
    if (mclamp && fu_ok) {
        g_clamp_site = find_clamp_site((const uint8_t *)il2_method_ptr(mfu), (const uint8_t *)il2_method_ptr(mclamp));
        gs3_log("clamp call-site: %p (%s)", g_clamp_site, g_clamp_site ? "exact" : "not found -> heuristic filter");
        g_hs_clamp = install("UnityEngine.Mathf.Clamp(float)", mclamp, (void *)hk_Clamp, (void **)&o_Clamp) ? HS_OK : HS_FAIL;
    } else {
        gs3_log("speed: Mathf.Clamp(float)=%p playermovement.FixedUpdate hook=%d", (void *)mclamp, fu_ok);
        g_hs_clamp = HS_FAIL;
    }

    g_hs_ohk = (K_dcs && install("DamageCalcScript.ProcessResists", il2_find_method(K_dcs, "ProcessResists", 2), (void *)hk_Resists, (void **)&o_Resists)) ? HS_OK : HS_FAIL;

    int m1 = K_themap && M.tm_chunkRenderers > 0 && M.tm_saveIcons > 0 && M.tm_bbIcons > 0 && MI_setenabled;
    g_hs_map = (m1 && install("themap.Show", il2_find_method(K_themap, "Show", 1), (void *)hk_Show, (void **)&o_Show)
                   && install("themap.displayChunks", il2_find_method(K_themap, "displayChunks", 0), (void *)hk_map_display, (void **)&o_map_display)) ? HS_OK : HS_FAIL;

    if (g_hs_tick == HS_NONE) g_hs_tick = HS_OK;          /* validate_statics() may already have flagged a mismatch */
    gs3_log("hooks installed: tick=OK dmg=%d jump=%d clamp=%d ohk=%d map=%d", g_hs_dmg, g_hs_jump, g_hs_clamp, g_hs_ohk, g_hs_map);
    return 0;
}
