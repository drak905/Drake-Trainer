/*
 * Ghost Song Trainer v3 - shared declarations (C core <-> C++ ImGui overlay).
 *
 * Thread model (important):
 *   - game thread  : status.Update / status.FixedUpdate hooks.  ONLY this thread touches il2cpp objects.
 *   - hotkey thread: polls the F-keys, flips feature flags / posts one-shot requests.
 *   - render thread: IDXGISwapChain::Present hook -> ImGui.  Reads the published snapshot only.
 */
#ifndef GS3_H
#define GS3_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define GS3_VERSION "3.0.0"

/* ---- toggles (each one can be switched on/off independently) ---- */
enum Gs3Feature {
    FT_GOD = 0,   /* F1  no damage, cannot die                          */
    FT_MONEY,     /* F3  keep Nanites / Bugblood topped up              */
    FT_ITEMS,     /* F3  keep consumables stocked (+ heal fuel)         */
    FT_SEEDS,     /*     (menu) also keep permanent-stat consumables    */
    FT_JUMP,      /* F4  unlimited air jumps                            */
    FT_SPEED,     /* F5  run speed x N                                  */
    FT_OHK,       /* F6  one-hit kill                                   */
    FT_STAMINA,   /* F8  infinite stamina + spirit (mana)               */
    FT_AMMO,      /*     (menu) infinite ammo, no gun overheat          */
    FT_MAPALL,    /* F9  whole map + all item/save icons visible        */
    FT__COUNT
};

/* ---- one-shot actions (executed on the game thread) ---- */
enum Gs3Action {
    AC_ADDMONEY = 0,  /* F2  */
    AC_HEAL,          /* F7  */
    AC_GIVEALL,       /* F11 */
    AC_UNLOCKMAP,     /*     (menu) write mapChunksOwned (saved) */
    AC_DIAG,          /* F12 */
    AC__COUNT
};

/* hook / resolution status per feature (for the menu + self-test) */
enum { HS_NONE = 0, HS_OK = 1, HS_FAIL = 2 };

typedef struct Gs3Snapshot {
    int   valid;                   /* a running game was found */
    float hp, hpmax, spirit, spiritmax, stamina, staminamax, ammo, ammomax;
    int   nanites, blood, heals;
    int   map_site_ok;
} Gs3Snapshot;

typedef struct Gs3Settings {
    int   money_amount;     /* AC_ADDMONEY amount                  */
    float speed_mult;       /* FT_SPEED multiplier (1.5 .. 4)      */
    float ui_scale;         /* menu scale                          */
    int   hud_strip;        /* active-cheat strip when menu closed */
    int   money_target;     /* FT_MONEY keeps Nanites >= this      */
} Gs3Settings;

extern Gs3Settings g_set;

/* feature API */
int         gs3_feature_get(int id);
void        gs3_feature_set(int id, int on);
void        gs3_feature_toggle(int id);
void        gs3_action(int id);
int         gs3_feature_status(int id);       /* HS_* */
const char *gs3_feature_name(int id);
const char *gs3_feature_hotkey(int id);       /* "F1" or "" */
const char *gs3_action_name(int id);
const char *gs3_action_hotkey(int id);
int         gs3_action_status(int id);
void        gs3_get_snapshot(Gs3Snapshot *out);
void        gs3_settings_save(void);
void        gs3_toast(const char *fmt, ...);
int         gs3_toast_get(char *buf, int cap);   /* returns remaining ms (0 = none) */
void        gs3_log(const char *fmt, ...);
int         gs3_giveall_busy(void);

/* overlay API (overlay.cpp) */
void gs3_overlay_start(void);
int  gs3_overlay_menu_open(void);
void gs3_overlay_menu_toggle(void);
unsigned gs3_overlay_frames(void);
int  gs3_overlay_status(void);                /* HS_* */

#ifdef __cplusplus
}
#endif
#endif
