/*
 * Ghost Song trainer - interface between the game logic (gs_trainer.c) and the
 * in-game Dear ImGui overlay (gs_overlay.cpp).
 *
 * Threading rules
 *   - Every il2cpp call happens on the game's main thread (status.LateUpdate
 *     hook).  The overlay (render thread) and the hotkey thread only flip
 *     volatile flags / post requests; gs_trainer.c executes them.
 *   - The overlay never touches il2cpp: it reads a GsSnapshot that the main
 *     thread refreshes ~10x per second.
 */
#ifndef GS_TRAINER_H
#define GS_TRAINER_H

#ifdef __cplusplus
extern "C" {
#endif

#define GS_TRAINER_VERSION "2.0"

/* toggles */
enum {
    GS_F_GOD = 0,
    GS_F_INFSPIRIT,
    GS_F_INFJUMP,
    GS_F_SPEED2,
    GS_F_ONEHIT,
    GS_F_INFSTAM,
    GS_F_COUNT
};

/* one-shot actions */
enum {
    GS_A_ADDMONEY = 0,
    GS_A_HEAL,
    GS_A_REVEAL,
    GS_A_GIVEITEMS,
    GS_A_DIAG,
    GS_A_COUNT
};

typedef struct GsSnapshot {
    int   have_status;                 /* 1 once a save / new game is running */
    float hp, hpmax;
    float spirit, spiritcap;
    float stamina, staminamax;
    long  hooks_ok;                    /* of 4 */
    long  ticks, kills, speedcalls;
    int   toggles[GS_F_COUNT];
    int   add_amount;                  /* amount used by "+ spirit" */
} GsSnapshot;

/* ---- provided by gs_trainer.c ---- */
void gs_get_snapshot(GsSnapshot *out);
int  gs_feature_get(int id);
void gs_feature_set(int id, int on);        /* thread-safe */
void gs_feature_toggle(int id);             /* thread-safe */
void gs_action(int id);                     /* thread-safe, runs on the game thread */
void gs_set_add_amount(int amount);
const char *gs_dir(void);                   /* folder of GhostSong.exe, no trailing '\' */
void gs_log(const char *fmt, ...);

/* ---- provided by gs_overlay.cpp ---- */
void gs_overlay_start(void);                /* spawns the Present-hook thread */
void gs_overlay_toggle_menu(void);          /* F10 / Insert */
void gs_overlay_toast(const char *en, const char *vi);   /* short message at the top of the screen (UTF-8) */
long gs_overlay_frames(void);               /* frames drawn so far (0 = overlay not alive) */
int  gs_overlay_menu_open(void);
void gs_overlay_set_menu_open(int open);

#ifdef __cplusplus
}
#endif
#endif /* GS_TRAINER_H */
