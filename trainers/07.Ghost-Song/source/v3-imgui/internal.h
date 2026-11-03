#ifndef GS3_INTERNAL_H
#define GS3_INTERNAL_H

#include <windows.h>
#include "gs3.h"
#include "il2.h"

extern char g_dir[MAX_PATH];                 /* folder of GhostSong.exe (with trailing \) */
extern volatile LONG g_ft[FT__COUNT];        /* feature switches                          */
extern volatile LONG g_req[AC__COUNT];       /* pending one-shot requests                 */

/* hook / resolution status, filled by game.c */
extern int g_hs_tick, g_hs_jump, g_hs_clamp, g_hs_ohk, g_hs_map, g_hs_dmg, g_hs_rest, g_hs_mapfn;

/* counters used by the self-test and the diagnostics */
extern volatile LONG g_cnt_dmg_blocked, g_cnt_ohk_calls, g_cnt_ohk_boost, g_cnt_clamp_calls, g_cnt_clamp_scaled,
                     g_cnt_jump_calls, g_cnt_jump_assist, g_cnt_map_show, g_cnt_ticks, g_cnt_fixed;

/* core.c */
int  gs3_selftest_requested(void);
void gs3_now_str(char *buf, int cap);

/* game.c */
int  game_init(void);                        /* resolve metadata + install hooks (init thread) */
void game_diag(void);                        /* write diagnostics to the log (game thread)     */

/* selftest.c (runs on the game thread, called from the Update tick) */
void selftest_step(void *status);
int  selftest_active(void);

/* helpers shared by game.c / selftest.c */
extern Il2CppClass *K_status, *K_charcon, *K_global, *K_pm, *K_dcs, *K_themap, *K_iteminfo, *K_mods;
void *game_status(void);                     /* global.statstat or NULL */
int   game_in_gameplay(void *st);
int   game_do_add_money(int amount);         /* direct, returns new Nanites */
int   game_nanites(void *st);
void  game_set_nanites(void *st, int v);
float game_health(void);
void  game_set_health(float v);
float game_health_max(void);
float game_stamina(void *st);
void  game_set_stamina(void *st, float v);
float game_stamina_max(void *st);
int   game_item_owned(void *st, int idx);
void  game_set_item_owned(void *st, int idx, int v);
int   game_item_count(void *st);
void  game_apply_all(void *st);              /* run the per-tick feature logic once */
void  game_request_service(void *st);
float game_get_ammo(void);
void  game_set_ammo(float v);
float game_ammo_max(void);
int   game_map_info(int *chunkRenderers, int *chunksOwned);

#endif
