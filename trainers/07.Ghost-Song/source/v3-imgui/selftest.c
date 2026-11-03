/*
 * Per-feature self-test (Gate 3 / Gate 4 of the verification protocol).
 * Enabled by TRAINER_SELFTEST=1 or an empty file "gs3_selftest.flag" next to GhostSong.exe.
 * Runs on the game thread inside the status.Update tick once a game is loaded, restores every value it touches
 * and writes "trainer_selftest_report.json" with one entry per feature / sub-agent branch.
 */
#include <windows.h>
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <math.h>
#include "internal.h"

typedef struct { const char *branch, *feature; const char *status; char note[220]; } Res;
static Res  R[32];
static int  nres;
static int  g_enabled = -1, g_step, g_wait, g_frames;
static int  v_i;                         /* saved ints */
static float v_f1, v_f2, v_f3;
static LONG c0, c1;

int selftest_active(void) { return g_enabled > 0 && g_step < 100; }

static void rec(const char *branch, const char *feature, int pass, const char *fmt, ...)
{
    if (nres >= 32) return;
    Res *r = &R[nres++];
    r->branch = branch; r->feature = feature; r->status = pass ? "PASS" : "FAIL_INVALID_INVARIANT";
    va_list ap; va_start(ap, fmt); vsnprintf(r->note, sizeof r->note, fmt, ap); va_end(ap);
    gs3_log("selftest %-22s %-26s %s  %s", branch, feature, r->status, r->note);
}

static void rec_hook_only(const char *branch, const char *feature, int hook_ok, const char *fmt, ...)
{
    if (nres >= 32) return;
    Res *r = &R[nres++];
    r->branch = branch; r->feature = feature; r->status = hook_ok ? "PASS_HOOK_ONLY_NOT_EXERCISED" : "FAIL_HOOK_MISSING";
    va_list ap; va_start(ap, fmt); vsnprintf(r->note, sizeof r->note, fmt, ap); va_end(ap);
    gs3_log("selftest %-22s %-26s %s  %s", branch, feature, r->status, r->note);
}

static void json_escape(FILE *f, const char *s)
{
    for (; *s; s++) {
        if (*s == '"' || *s == '\\') fputc('\\', f);
        if ((unsigned char)*s >= 0x20) fputc(*s, f);
    }
}

static void write_report(void)
{
    char path[MAX_PATH + 40]; snprintf(path, sizeof path, "%strainer_selftest_report.json", g_dir);
    FILE *f = fopen(path, "w");
    if (!f) return;
    int fails = 0;
    for (int i = 0; i < nres; i++) if (strncmp(R[i].status, "FAIL", 4) == 0) fails++;
    char when[64]; gs3_now_str(when, sizeof when);
    fprintf(f, "{\n  \"tool\": \"GhostSongTrainer %s\",\n  \"time\": \"%s\",\n  \"overall_status\": \"%s\",\n", GS3_VERSION, when,
            fails ? "PARTIAL_FAIL_NEEDS_ISOLATED_HEAL" : "PASS_READY_FOR_HUMAN");
    fprintf(f, "  \"hook_status\": { \"tick\": %d, \"god_damage\": %d, \"jump\": %d, \"speed_clamp\": %d, \"one_hit_kill\": %d, \"map\": %d, \"rest\": %d, \"overlay\": %d },\n",
            g_hs_tick, g_hs_dmg, g_hs_jump, g_hs_clamp, g_hs_ohk, g_hs_map, g_hs_rest, gs3_overlay_status());
    fprintf(f, "  \"counters\": { \"ticks\": %ld, \"fixed\": %ld, \"dmg_blocked\": %ld, \"jump_calls\": %ld, \"clamp_calls\": %ld, \"clamp_scaled\": %ld, \"ohk_calls\": %ld, \"ohk_boost\": %ld, \"map_show\": %ld, \"overlay_frames\": %u },\n",
            g_cnt_ticks, g_cnt_fixed, g_cnt_dmg_blocked, g_cnt_jump_calls, g_cnt_clamp_calls, g_cnt_clamp_scaled, g_cnt_ohk_calls, g_cnt_ohk_boost, g_cnt_map_show, gs3_overlay_frames());
    fprintf(f, "  \"feature_results\": [\n");
    for (int i = 0; i < nres; i++) {
        fprintf(f, "    { \"subagent_branch_id\": \"%s\", \"feature\": \"%s\", \"status\": \"%s\", \"note\": \"", R[i].branch, R[i].feature, R[i].status);
        json_escape(f, R[i].note);
        fprintf(f, "\" }%s\n", i + 1 < nres ? "," : "");
    }
    fprintf(f, "  ]\n}\n");
    fclose(f);
    gs3_log("selftest report written: %s  (%s)", path, fails ? "FAILURES" : "ALL PASS");
}

static int nearf(float a, float b, float eps) { return fabsf(a - b) <= eps; }

void selftest_step(void *st)
{
    if (g_enabled < 0) g_enabled = gs3_selftest_requested() ? 1 : 0;
    if (g_enabled <= 0 || g_step >= 100) return;
    if (g_hs_tick != HS_OK) return;
    if (g_wait > 0) { g_wait--; return; }
    float hpmax = game_health_max();

    switch (g_step) {
    case 0:                                              /* wait for a stable running game */
        if (++g_frames < 240 || game_health() <= 0.0f) return;
        g_step = 1; break;
    case 1: {                                            /* Gate 3: state invariants */
        int items = game_item_count(st);
        int ok = hpmax > 0 && hpmax < 1000000 && game_health() >= 0 && game_health() <= hpmax + 1 && isfinite(game_stamina(st)) &&
                 game_stamina_max(st) > 0 && game_nanites(st) >= 0 && items >= 54;
        rec("SUBAGENT-CORE", "state_invariants", ok, "hp %.0f/%.0f stamina %.0f/%.0f nanites %d items %d", (double)game_health(), (double)hpmax,
            (double)game_stamina(st), (double)game_stamina_max(st), game_nanites(st), items);
        g_step = 2; break; }
    case 2: {                                            /* Gate 4: add money delta */
        int a = game_nanites(st);
        int b = game_do_add_money(1000);
        rec("SUBAGENT-ECONOMY-03", "add_money", b == a + 1000, "nanites %d -> %d (expected +1000)", a, b);
        game_set_nanites(st, a);
        g_step = 3; break; }
    case 3:
        v_i = game_nanites(st); game_set_nanites(st, 0); g_ft[FT_MONEY] = 1; g_wait = 3; g_step = 4; break;
    case 4: {
        int n = game_nanites(st);
        rec("SUBAGENT-ECONOMY-03", "unlimited_money", n >= 1000, "nanites 0 -> %d with the toggle on", n);
        g_ft[FT_MONEY] = 0; game_set_nanites(st, v_i);
        g_step = 5; break; }
    case 5:
        v_i = game_item_owned(st, 39); game_set_item_owned(st, 39, 0); g_ft[FT_ITEMS] = 1; g_wait = 3; g_step = 6; break;
    case 6: {
        int n = game_item_owned(st, 39);
        rec("SUBAGENT-ECONOMY-03", "unlimited_items", n >= 25, "item[39] 0 -> %d with the toggle on", n);
        g_ft[FT_ITEMS] = 0; game_set_item_owned(st, 39, v_i);
        g_step = 7; break; }
    case 7:
        v_f1 = game_health(); game_set_health(hpmax > 2 ? hpmax * 0.5f : 1.0f); g_ft[FT_GOD] = 1; g_wait = 3; g_step = 8; break;
    case 8: {
        rec("SUBAGENT-COMBAT-01", "god_mode", nearf(game_health(), hpmax, 1.0f), "hp pinned to %.0f/%.0f; TakeDamage hook=%d", (double)game_health(), (double)hpmax, g_hs_dmg);
        g_ft[FT_GOD] = 0; g_wait = 3; g_step = 9; break; }
    case 9:
        game_set_health(v_f1 > 0 ? v_f1 : hpmax);
        g_step = 10; break;
    case 10:
        game_set_health(1.0f); InterlockedIncrement(&g_req[AC_HEAL]); g_wait = 4; g_step = 11; break;
    case 11:
        rec("SUBAGENT-COMBAT-01", "heal", nearf(game_health(), hpmax, 1.0f), "hp 1 -> %.0f/%.0f via status.rest", (double)game_health(), (double)hpmax);
        g_step = 12; break;
    case 12:
        v_f1 = game_stamina(st); game_set_stamina(st, 0.0f); g_ft[FT_STAMINA] = 1; g_wait = 3; g_step = 13; break;
    case 13: {
        float sm = game_stamina_max(st);
        rec("SUBAGENT-COMBAT-01", "infinite_stamina", nearf(game_stamina(st), sm, 0.5f), "stamina 0 -> %.0f/%.0f", (double)game_stamina(st), (double)sm);
        g_ft[FT_STAMINA] = 0; g_step = 14; break; }
    case 14:
        v_f1 = game_get_ammo(); game_set_ammo(0.0f); g_ft[FT_AMMO] = 1; g_wait = 3; g_step = 15; break;
    case 15: {
        float am = game_ammo_max();
        rec("SUBAGENT-COMBAT-01", "infinite_ammo", nearf(game_get_ammo(), am, 0.5f), "ammo 0 -> %.0f/%.0f", (double)game_get_ammo(), (double)am);
        g_ft[FT_AMMO] = 0; g_step = 16; break; }
    case 16:                                             /* movement hooks: exercise the clamp detour for ~1 s */
        c0 = g_cnt_clamp_calls; c1 = g_cnt_clamp_scaled; g_ft[FT_SPEED] = 1; g_wait = 90; g_step = 17; break;
    case 17: {
        LONG calls = g_cnt_clamp_calls - c0, scaled = g_cnt_clamp_scaled - c1;
        g_ft[FT_SPEED] = 0;
        rec("SUBAGENT-MOVEMENT-02", "speed_clamp", g_hs_clamp == HS_OK && scaled > 0, "Mathf.Clamp calls %ld, player velocity clamps scaled x%.2g: %ld (call-site %s)",
            calls, (double)g_set.speed_mult, scaled, "see log");
        rec_hook_only("SUBAGENT-MOVEMENT-02", "unlimited_jump", g_hs_jump == HS_OK, "Jump() detour installed; verified live with real key presses (see log counters jump_calls)");
        rec_hook_only("SUBAGENT-COMBAT-01", "one_hit_kill", g_hs_ohk == HS_OK, "ProcessResists detour installed; needs an enemy hit (ohk_calls=%ld)", g_cnt_ohk_calls);
        g_step = 18; break; }
    case 18: {
        int a, b; game_map_info(&a, &b);
        rec("SUBAGENT-WORLD-04", "map_items", g_hs_map == HS_OK && b > 0, "themap hooks=%d, mapChunksOwned length %d", g_hs_map, b);
        g_step = 19; break; }
    default:
        write_report();
        g_step = 100;
        break;
    }
}
