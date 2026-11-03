/*
 *  Ghost Song trainer - in-game overlay (Dear ImGui on the game's own D3D11 swap chain)
 *
 *  Ghost Song is a Unity 2020.3 game rendering with Direct3D 11.  Instead of
 *  opening a separate Win32 window next to the game (v1.0), the trainer menu
 *  is now drawn INSIDE the game frame:
 *
 *    1. a throw-away D3D11 device + swap chain on a hidden window is created
 *       once, only to read the address of IDXGISwapChain::Present from the vtable;
 *    2. that function is detoured with MinHook (the same library the game logic
 *       uses);  every frame hk_present() draws the ImGui menu on the back buffer
 *       and then calls the real Present;
 *    3. the game window's WndProc is subclassed so that, while the menu is open,
 *       mouse / keyboard messages go to ImGui instead of the game.
 *
 *  Nothing here touches il2cpp: the menu reads a GsSnapshot and posts requests
 *  (gs_feature_set / gs_action) that gs_trainer.c executes on the game thread.
 */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <d3d11.h>
#include <d3dcompiler.h>
#include <dxgi.h>
#include <stdio.h>
#include <string.h>
#include <math.h>

#include "imgui.h"
#include "imgui_impl_win32.h"
#include "imgui_impl_dx11.h"
#include "MinHook.h"
#include "gs_trainer.h"

extern IMGUI_IMPL_API LRESULT ImGui_ImplWin32_WndProcHandler(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);

/* ------------------------------------------------------------------ state */
typedef HRESULT (STDMETHODCALLTYPE *PresentFn)(IDXGISwapChain *, UINT, UINT);
typedef HRESULT (WINAPI *D3D11CreateDeviceAndSwapChainFn)(
    IDXGIAdapter *, D3D_DRIVER_TYPE, HMODULE, UINT, const D3D_FEATURE_LEVEL *, UINT, UINT,
    const DXGI_SWAP_CHAIN_DESC *, IDXGISwapChain **, ID3D11Device **, D3D_FEATURE_LEVEL *,
    ID3D11DeviceContext **);

static PresentFn          o_present;
static volatile LONG      g_frames;
static volatile LONG      g_menu_open;
static volatile LONG      g_menu_toggle_req;
static volatile LONG      g_failed;
static bool               g_ready;              /* ImGui + backends initialised */
static HWND               g_hwnd;
static WNDPROC            g_orig_wndproc;
static ID3D11Device      *g_dev;                /* only compared, never dereferenced */
static bool               g_font_vi_ok;
static ImGuiStyle         g_base_style;
static float              g_applied_scale = -1.0f;
static DWORD              g_first_frame_tick;

/* persisted settings (gs_trainer.ini) */
static char  g_ini[MAX_PATH];
static char  g_imgui_ini[MAX_PATH];
static int   g_lang;                            /* 0 = English, 1 = Vietnamese */
static float g_user_scale = 1.0f;
static int   g_hud = 1;
static int   g_amount = 10000;

/* ImGui is not thread-safe: the WndProc (main thread) and the Present hook (render thread) share this lock */
static CRITICAL_SECTION g_imgui_cs;
struct CsGuard { CsGuard() { EnterCriticalSection(&g_imgui_cs); } ~CsGuard() { LeaveCriticalSection(&g_imgui_cs); } };

/* toast */
static CRITICAL_SECTION g_toast_cs;
static char  g_toast_en[160], g_toast_vi[160];
static DWORD g_toast_tick;

/* ------------------------------------------------------------------ helpers */
static const char *T(const char *en, const char *vi) { return (g_lang == 1 && g_font_vi_ok) ? vi : en; }

static void ini_load(void) {
    g_lang       = GetPrivateProfileIntA("ui", "language_vi", 0, g_ini) ? 1 : 0;
    g_user_scale = GetPrivateProfileIntA("ui", "scale_percent", 100, g_ini) / 100.0f;
    g_hud        = GetPrivateProfileIntA("ui", "hud", 1, g_ini) ? 1 : 0;
    g_amount     = GetPrivateProfileIntA("ui", "add_amount", 10000, g_ini);
    if (g_user_scale < 0.5f) g_user_scale = 0.5f;
    if (g_user_scale > 2.5f) g_user_scale = 2.5f;
    if (g_amount < 1) g_amount = 1;
    gs_set_add_amount(g_amount);
}

static void ini_save(void) {
    char b[32];
    WritePrivateProfileStringA("ui", "language_vi", g_lang ? "1" : "0", g_ini);
    snprintf(b, sizeof b, "%d", (int)(g_user_scale * 100.0f + 0.5f));
    WritePrivateProfileStringA("ui", "scale_percent", b, g_ini);
    WritePrivateProfileStringA("ui", "hud", g_hud ? "1" : "0", g_ini);
    snprintf(b, sizeof b, "%d", g_amount);
    WritePrivateProfileStringA("ui", "add_amount", b, g_ini);
}

extern "C" void gs_overlay_toast(const char *en, const char *vi) {
    if (!en) return;
    EnterCriticalSection(&g_toast_cs);
    snprintf(g_toast_en, sizeof g_toast_en, "%s", en);
    snprintf(g_toast_vi, sizeof g_toast_vi, "%s", vi ? vi : en);
    g_toast_tick = GetTickCount();
    LeaveCriticalSection(&g_toast_cs);
}
extern "C" long gs_overlay_frames(void) { return g_frames; }
extern "C" int  gs_overlay_menu_open(void) { return g_menu_open ? 1 : 0; }
extern "C" void gs_overlay_toggle_menu(void) { InterlockedExchange(&g_menu_toggle_req, 1); }
extern "C" void gs_overlay_set_menu_open(int open) { InterlockedExchange(&g_menu_open, open ? 1 : 0); }

/* ------------------------------------------------------------------ D3DCompile shim
 * imgui_impl_dx11 compiles its two tiny shaders at run time with D3DCompile.
 * Instead of importing d3dcompiler_47.dll statically (a missing DLL would stop
 * the whole game from starting, because this dll is loaded at process start),
 * resolve it lazily; if it is not present the overlay simply fails to init. */
extern "C" HRESULT WINAPI D3DCompile(LPCVOID src, SIZE_T size, LPCSTR srcName, const D3D_SHADER_MACRO *defines,
                                     ID3DInclude *include, LPCSTR entry, LPCSTR target, UINT f1, UINT f2,
                                     ID3DBlob **code, ID3DBlob **errors) {
    typedef HRESULT (WINAPI *Fn)(LPCVOID, SIZE_T, LPCSTR, const D3D_SHADER_MACRO *, ID3DInclude *, LPCSTR, LPCSTR,
                                 UINT, UINT, ID3DBlob **, ID3DBlob **);
    static Fn fn;
    if (!fn) {
        static const char *const dlls[] = { "d3dcompiler_47.dll", "d3dcompiler_46.dll", "d3dcompiler_43.dll" };
        for (const char *d : dlls) {
            HMODULE m = LoadLibraryA(d);
            if (m) { fn = (Fn)GetProcAddress(m, "D3DCompile"); if (fn) break; }
        }
    }
    if (!fn) return E_FAIL;
    return fn(src, size, srcName, defines, include, entry, target, f1, f2, code, errors);
}

/* ------------------------------------------------------------------ window proc */
static LRESULT CALLBACK hk_wndproc(HWND h, UINT m, WPARAM w, LPARAM l) {
    if (g_menu_open && g_ready) {
        LRESULT r;
        { CsGuard lock; r = ImGui_ImplWin32_WndProcHandler(h, m, w, l); }
        switch (m) {
        case WM_SETCURSOR:
            if (r) return r;                         /* ImGui draws its own cursor */
            break;
        case WM_MOUSEMOVE: case WM_MOUSEWHEEL: case WM_MOUSEHWHEEL:
        case WM_LBUTTONDOWN: case WM_LBUTTONUP: case WM_LBUTTONDBLCLK:
        case WM_RBUTTONDOWN: case WM_RBUTTONUP: case WM_RBUTTONDBLCLK:
        case WM_MBUTTONDOWN: case WM_MBUTTONUP: case WM_MBUTTONDBLCLK:
        case WM_XBUTTONDOWN: case WM_XBUTTONUP: case WM_XBUTTONDBLCLK:
        case WM_NCMOUSEMOVE:
            return 0;                                /* the game must not see the mouse */
        case WM_KEYDOWN: case WM_CHAR: case WM_UNICHAR: case WM_IME_CHAR:
            return 0;                                /* ... nor the keyboard (key-ups still pass,
                                                        WM_SYSKEYDOWN too: Alt+Enter / Alt+F4 work) */
        case WM_INPUT:
            return DefWindowProcW(h, m, w, l);       /* raw mouse/keyboard: swallow, but free the buffer */
        default: break;
        }
    }
    return CallWindowProcW(g_orig_wndproc, h, m, w, l);
}

/* ------------------------------------------------------------------ fonts / style */
static bool file_exists(const char *p) { DWORD a = GetFileAttributesA(p); return a != INVALID_FILE_ATTRIBUTES && !(a & FILE_ATTRIBUTE_DIRECTORY); }

static bool load_fonts(ImGuiIO &io) {
    char win[MAX_PATH];
    if (!GetWindowsDirectoryA(win, sizeof win)) win[0] = 0;
    static const char *const names[] = { "segoeui.ttf", "tahoma.ttf", "arial.ttf" };
    for (const char *n : names) {
        char path[MAX_PATH];
        snprintf(path, sizeof path, "%s\\Fonts\\%s", win, n);
        if (!file_exists(path)) continue;
        ImFontConfig cfg;
        cfg.OversampleH = 2;
        cfg.OversampleV = 1;
        ImFont *f = io.Fonts->AddFontFromFileTTF(path, 18.0f, &cfg, io.Fonts->GetGlyphRangesVietnamese());
        if (f) { gs_log("overlay: font %s (Vietnamese glyphs)", n); return true; }
    }
    io.Fonts->AddFontDefault();
    gs_log("overlay: no system font found - ASCII fallback, Vietnamese labels disabled");
    return false;
}

static void setup_style(void) {
    ImGui::StyleColorsDark();
    ImGuiStyle &s = ImGui::GetStyle();
    s.WindowRounding = 8.0f; s.FrameRounding = 5.0f; s.GrabRounding = 5.0f; s.PopupRounding = 5.0f;
    s.ChildRounding = 5.0f; s.ScrollbarRounding = 6.0f; s.TabRounding = 5.0f;
    s.WindowPadding = ImVec2(12, 10); s.ItemSpacing = ImVec2(8, 7); s.FramePadding = ImVec2(8, 4);
    s.WindowBorderSize = 1.0f; s.FrameBorderSize = 0.0f;
    ImVec4 *c = s.Colors;
    const ImVec4 accent(0.28f, 0.74f, 0.82f, 1.0f);
    c[ImGuiCol_WindowBg]        = ImVec4(0.06f, 0.07f, 0.10f, 0.94f);
    c[ImGuiCol_Border]          = ImVec4(0.28f, 0.74f, 0.82f, 0.45f);
    c[ImGuiCol_TitleBg]         = ImVec4(0.07f, 0.12f, 0.16f, 1.0f);
    c[ImGuiCol_TitleBgActive]   = ImVec4(0.09f, 0.24f, 0.30f, 1.0f);
    c[ImGuiCol_FrameBg]         = ImVec4(0.14f, 0.16f, 0.21f, 1.0f);
    c[ImGuiCol_FrameBgHovered]  = ImVec4(0.20f, 0.30f, 0.36f, 1.0f);
    c[ImGuiCol_FrameBgActive]   = ImVec4(0.24f, 0.38f, 0.45f, 1.0f);
    c[ImGuiCol_CheckMark]       = accent;
    c[ImGuiCol_SliderGrab]      = accent;
    c[ImGuiCol_SliderGrabActive]= ImVec4(0.45f, 0.88f, 0.95f, 1.0f);
    c[ImGuiCol_Button]          = ImVec4(0.13f, 0.34f, 0.41f, 1.0f);
    c[ImGuiCol_ButtonHovered]   = ImVec4(0.19f, 0.50f, 0.60f, 1.0f);
    c[ImGuiCol_ButtonActive]    = ImVec4(0.24f, 0.62f, 0.73f, 1.0f);
    c[ImGuiCol_Header]          = ImVec4(0.13f, 0.28f, 0.34f, 1.0f);
    c[ImGuiCol_HeaderHovered]   = ImVec4(0.19f, 0.42f, 0.50f, 1.0f);
    c[ImGuiCol_HeaderActive]    = ImVec4(0.24f, 0.52f, 0.62f, 1.0f);
    g_base_style = s;
    g_applied_scale = -1.0f;
}

static void apply_scale(float sc) {
    if (fabsf(sc - g_applied_scale) < 0.01f) return;
    ImGui::GetStyle() = g_base_style;
    ImGui::GetStyle().ScaleAllSizes(sc);
    ImGui::GetIO().FontGlobalScale = sc;
    g_applied_scale = sc;
}

/* ------------------------------------------------------------------ menu widgets */
static void feature_cb(int id, const char *en, const char *vi, const char *hk, const char *tip_en, const char *tip_vi) {
    char buf[200];
    snprintf(buf, sizeof buf, "%s  [%s]###f%d", T(en, vi), hk, id);
    bool v = gs_feature_get(id) != 0;
    if (ImGui::Checkbox(buf, &v)) gs_feature_set(id, v ? 1 : 0);
    if (ImGui::IsItemHovered()) ImGui::SetTooltip("%s", T(tip_en, tip_vi));
}

static bool action_btn(const GsSnapshot &s, int id, const char *en, const char *vi, const char *hk,
                       const char *tip_en, const char *tip_vi, float width) {
    char buf[200];
    snprintf(buf, sizeof buf, "%s  [%s]###a%d", T(en, vi), hk, id);
    ImGui::BeginDisabled(!s.have_status);
    bool pressed = ImGui::Button(buf, ImVec2(width, 0));
    ImGui::EndDisabled();
    if (ImGui::IsItemHovered(ImGuiHoveredFlags_AllowWhenDisabled)) ImGui::SetTooltip("%s", T(tip_en, tip_vi));
    if (pressed) gs_action(id);
    return pressed;
}

static void stat_bar(const char *name, float cur, float mx, const ImVec4 &col) {
    float frac = (mx > 0.0f) ? cur / mx : 0.0f;
    if (frac < 0.0f) frac = 0.0f;
    if (frac > 1.0f) frac = 1.0f;
    char txt[96];
    snprintf(txt, sizeof txt, "%s  %.0f / %.0f", name, cur, mx);
    ImGui::PushStyleColor(ImGuiCol_PlotHistogram, col);
    ImGui::ProgressBar(frac, ImVec2(-1.0f, 0.0f), txt);
    ImGui::PopStyleColor();
}

static void draw_menu(const GsSnapshot &s, float sc) {
    ImGui::SetNextWindowPos(ImVec2(40.0f * sc, 60.0f * sc), ImGuiCond_FirstUseEver);
    ImGui::SetNextWindowSizeConstraints(ImVec2(430.0f * sc, 0.0f), ImVec2(700.0f * sc, 1e9f));
    bool open = true;
    char title[96];
    snprintf(title, sizeof title, "Ghost Song Trainer  v%s###gs_trainer_main", GS_TRAINER_VERSION);
    if (!ImGui::Begin(title, &open, ImGuiWindowFlags_AlwaysAutoResize)) { ImGui::End(); if (!open) gs_overlay_set_menu_open(0); return; }

    if (!s.have_status) {
        ImGui::TextColored(ImVec4(1.0f, 0.75f, 0.30f, 1.0f), "%s",
            T("Waiting for a running game - load a save or start a new game.",
              "Đang chờ vào game - hãy tải file save hoặc bắt đầu game mới."));
    } else {
        stat_bar("HP", s.hp, s.hpmax, ImVec4(0.80f, 0.22f, 0.25f, 1.0f));
        stat_bar("Spirit", s.spirit, s.spiritcap, ImVec4(0.35f, 0.55f, 0.95f, 1.0f));
        stat_bar(T("Stamina", "Thể lực"), s.stamina, s.staminamax, ImVec4(0.25f, 0.75f, 0.40f, 1.0f));
    }
    ImGui::Spacing();

    if (ImGui::CollapsingHeader(T("Player", "Nhân vật"), ImGuiTreeNodeFlags_DefaultOpen)) {
        feature_cb(GS_F_GOD, "God mode", "Bất tử", "F1",
                   "Sets the game's own isImmortal flag and keeps health full.",
                   "Bật cờ isImmortal của chính game và giữ máu luôn đầy.");
        feature_cb(GS_F_INFSTAM, "Infinite stamina", "Thể lực vô hạn", "F8",
                   "Keeps stamina at its maximum.", "Giữ thể lực luôn ở mức tối đa.");
        feature_cb(GS_F_INFJUMP, "Unlimited jump", "Nhảy vô hạn", "F4",
                   "99 extra air jumps (charcon.extrajumps). Switching off restores the original value.",
                   "Thêm 99 lần nhảy trên không (charcon.extrajumps). Tắt sẽ trả về giá trị ban đầu.");
        feature_cb(GS_F_SPEED2, "Move speed x2", "Tốc độ di chuyển x2", "F5",
                   "Doubles the player's run speed.", "Nhân đôi tốc độ chạy của nhân vật.");
        action_btn(s, GS_A_HEAL, "Heal", "Hồi máu", "F7",
                   "Restores health to the maximum.", "Hồi đầy máu.", -1.0f);
    }
    if (ImGui::CollapsingHeader(T("Economy", "Kinh tế"), ImGuiTreeNodeFlags_DefaultOpen)) {
        ImGui::SetNextItemWidth(130.0f * sc);
        int amt = g_amount;
        if (ImGui::InputInt(T("Amount", "Số lượng"), &amt, 1000, 10000)) {
            if (amt < 1) amt = 1;
            if (amt > 1000000) amt = 1000000;
            g_amount = amt;
            gs_set_add_amount(g_amount);
        }
        if (ImGui::IsItemDeactivatedAfterEdit()) ini_save();
        action_btn(s, GS_A_ADDMONEY, "Add Spirit", "Thêm Spirit", "F2",
                   "Adds the amount and raises the Spirit cap by the same amount. This is saved in your game.",
                   "Cộng số lượng trên và nâng giới hạn Spirit tương ứng. Thay đổi này được lưu vào save.", -1.0f);
        feature_cb(GS_F_INFSPIRIT, "Infinite Spirit", "Spirit vô hạn", "F3",
                   "Cap 99999 and the balance is kept full. Switching off restores the original cap.",
                   "Giới hạn 99999 và luôn đầy. Tắt sẽ trả lại giới hạn ban đầu.");
    }
    if (ImGui::CollapsingHeader(T("Combat", "Chiến đấu"), ImGuiTreeNodeFlags_DefaultOpen)) {
        feature_cb(GS_F_ONEHIT, "One-hit kill", "Hạ gục 1 đòn", "F6",
                   "Any enemy that takes damage dies. Use with care on bosses.",
                   "Kẻ địch trúng đòn sẽ chết ngay. Cẩn thận khi dùng với boss.");
    }
    if (ImGui::CollapsingHeader(T("World", "Thế giới"), ImGuiTreeNodeFlags_DefaultOpen)) {
        float half = (ImGui::GetContentRegionAvail().x - ImGui::GetStyle().ItemSpacing.x) * 0.5f;
        action_btn(s, GS_A_REVEAL, "Show all on map", "Hiện toàn bộ bản đồ", "F9",
                   "Unlocks every map chunk.", "Mở khóa toàn bộ bản đồ.", half);
        ImGui::SameLine();
        /* give-all-items changes the save: ask for a second click */
        static DWORD armed_at = 0;
        bool armed = armed_at && (GetTickCount() - armed_at) < 3000;
        char buf[200];
        snprintf(buf, sizeof buf, "%s###gi", armed ? T("Click again to confirm!", "Bấm lần nữa để xác nhận!")
                                                  : T("Give all items  [F11]", "Nhận tất cả vật phẩm  [F11]"));
        ImGui::BeginDisabled(!s.have_status);
        if (ImGui::Button(buf, ImVec2(-1.0f, 0.0f))) {
            if (armed) { gs_action(GS_A_GIVEITEMS); armed_at = 0; } else armed_at = GetTickCount();
        }
        ImGui::EndDisabled();
        if (ImGui::IsItemHovered(ImGuiHoveredFlags_AllowWhenDisabled))
            ImGui::SetTooltip("%s", T("Gives every item, like the game's own cheat. Changes your save.",
                                      "Nhận mọi vật phẩm, giống mã cheat có sẵn của game. Thay đổi file save."));
    }
    if (ImGui::CollapsingHeader(T("Settings", "Cài đặt"))) {
        if (g_font_vi_ok) {
            int lang = g_lang;
            ImGui::SetNextItemWidth(170.0f * sc);
            if (ImGui::Combo(T("Language", "Ngôn ngữ"), &lang, "English\0Tiếng Việt\0")) { g_lang = lang; ini_save(); }
        }
        float us = g_user_scale;
        ImGui::SetNextItemWidth(170.0f * sc);
        if (ImGui::SliderFloat(T("UI scale", "Cỡ giao diện"), &us, 0.6f, 2.0f, "%.2f")) g_user_scale = us;
        if (ImGui::IsItemDeactivatedAfterEdit()) ini_save();
        bool hud = g_hud != 0;
        if (ImGui::Checkbox(T("Show active cheats on screen", "Hiện các tính năng đang bật trên màn hình"), &hud)) { g_hud = hud ? 1 : 0; ini_save(); }
        action_btn(s, GS_A_DIAG, "Write diagnostics to gs_trainer.log", "Ghi chẩn đoán vào gs_trainer.log", "F12",
                   "Dumps the current game state to gs_trainer.log (useful for bug reports).",
                   "Ghi trạng thái game hiện tại vào gs_trainer.log (hữu ích khi báo lỗi).", -1.0f);
    }
    ImGui::Spacing();
    ImGui::TextDisabled("%s", T("F10 / Insert: show / hide this menu", "F10 / Insert: hiện / ẩn menu này"));
    ImGui::TextDisabled("hooks %ld/4   ticks %ld   frames %ld", s.hooks_ok, s.ticks, (long)g_frames);
    ImGui::End();
    if (!open) gs_overlay_set_menu_open(0);
}

/* small always-on strip (menu closed): active cheats + a one-time hint */
static void draw_hud(const GsSnapshot &s, float sc) {
    static const char *const en[GS_F_COUNT] = { "God", "Inf.Spirit", "Inf.Jump", "Speed x2", "One-hit", "Inf.Stamina" };
    static const char *const vi[GS_F_COUNT] = { "Bất tử", "Spirit vô hạn", "Nhảy vô hạn", "Tốc độ x2", "Hạ 1 đòn", "Thể lực vô hạn" };
    char line[256]; line[0] = 0;
    int any = 0;
    for (int i = 0; i < GS_F_COUNT; i++) {
        if (!s.toggles[i]) continue;
        size_t n = strlen(line);
        snprintf(line + n, sizeof line - n, "%s%s", any ? "  |  " : "", T(en[i], vi[i]));
        any = 1;
    }
    char hint[160]; hint[0] = 0;
    DWORD since = GetTickCount() - g_first_frame_tick;
    if (since > 2000 && since < 17000)
        snprintf(hint, sizeof hint, "Ghost Song Trainer v%s - %s", GS_TRAINER_VERSION,
                 T("press F10 for the menu", "nhấn F10 để mở menu"));
    ImDrawList *dl = ImGui::GetForegroundDrawList();
    float x = 12.0f * sc, y = 8.0f * sc;
    if (g_hud && any) {
        char full[300]; snprintf(full, sizeof full, "TRAINER: %s", line);
        ImVec2 sz = ImGui::CalcTextSize(full);
        dl->AddRectFilled(ImVec2(x - 6 * sc, y - 3 * sc), ImVec2(x + sz.x + 6 * sc, y + sz.y + 3 * sc), IM_COL32(0, 0, 0, 140), 4.0f * sc);
        dl->AddText(ImVec2(x, y), IM_COL32(110, 225, 240, 255), full);
        y += sz.y + 10.0f * sc;
    }
    if (hint[0]) {
        ImVec2 sz = ImGui::CalcTextSize(hint);
        dl->AddRectFilled(ImVec2(x - 6 * sc, y - 3 * sc), ImVec2(x + sz.x + 6 * sc, y + sz.y + 3 * sc), IM_COL32(0, 0, 0, 140), 4.0f * sc);
        dl->AddText(ImVec2(x, y), IM_COL32(235, 235, 235, 255), hint);
    }
}

static void draw_toast(float sc) {
    char msg[200]; msg[0] = 0;
    EnterCriticalSection(&g_toast_cs);
    DWORD age = GetTickCount() - g_toast_tick;
    if (g_toast_tick && age < 2400) snprintf(msg, sizeof msg, "%s", T(g_toast_en, g_toast_vi));
    LeaveCriticalSection(&g_toast_cs);
    if (!msg[0]) return;
    float alpha = age > 1800 ? 1.0f - (age - 1800) / 600.0f : 1.0f;
    ImGuiIO &io = ImGui::GetIO();
    ImVec2 sz = ImGui::CalcTextSize(msg);
    ImVec2 p((io.DisplaySize.x - sz.x) * 0.5f, 40.0f * sc);
    ImDrawList *dl = ImGui::GetForegroundDrawList();
    dl->AddRectFilled(ImVec2(p.x - 14 * sc, p.y - 7 * sc), ImVec2(p.x + sz.x + 14 * sc, p.y + sz.y + 7 * sc),
                      IM_COL32(8, 20, 26, (int)(210 * alpha)), 8.0f * sc);
    dl->AddRect(ImVec2(p.x - 14 * sc, p.y - 7 * sc), ImVec2(p.x + sz.x + 14 * sc, p.y + sz.y + 7 * sc),
                IM_COL32(70, 190, 210, (int)(200 * alpha)), 8.0f * sc);
    dl->AddText(p, IM_COL32(255, 255, 255, (int)(255 * alpha)), msg);
}

/* ------------------------------------------------------------------ frame */
static const GUID kIID_ID3D11Device    = { 0xdb6f6ddb, 0xac77, 0x4e88, { 0x82, 0x53, 0x81, 0x9d, 0xf9, 0xbb, 0xf1, 0x40 } };
static const GUID kIID_ID3D11Texture2D = { 0x6f15aaf2, 0xd208, 0x4e89, { 0x9a, 0xb4, 0x48, 0x95, 0x35, 0xd3, 0x4f, 0x9c } };

static DXGI_FORMAT view_format(DXGI_FORMAT f) {
    switch (f) {
    case DXGI_FORMAT_R8G8B8A8_TYPELESS:    return DXGI_FORMAT_R8G8B8A8_UNORM;
    case DXGI_FORMAT_B8G8R8A8_TYPELESS:    return DXGI_FORMAT_B8G8R8A8_UNORM;
    case DXGI_FORMAT_B8G8R8X8_TYPELESS:    return DXGI_FORMAT_B8G8R8X8_UNORM;
    case DXGI_FORMAT_R10G10B10A2_TYPELESS: return DXGI_FORMAT_R10G10B10A2_UNORM;
    case DXGI_FORMAT_R16G16B16A16_TYPELESS:return DXGI_FORMAT_R16G16B16A16_FLOAT;
    default: return f;
    }
}

static void shutdown_imgui(void) {
    if (!g_ready) return;
    if (g_orig_wndproc && g_hwnd) SetWindowLongPtrW(g_hwnd, GWLP_WNDPROC, (LONG_PTR)g_orig_wndproc);
    g_orig_wndproc = NULL;
    ImGui_ImplDX11_Shutdown();
    ImGui_ImplWin32_Shutdown();
    ImGui::DestroyContext();
    g_ready = false; g_hwnd = NULL; g_dev = NULL;
}

static bool init_imgui(IDXGISwapChain *sc, ID3D11Device *dev, ID3D11DeviceContext *ctx, HWND hwnd) {
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO &io = ImGui::GetIO();
    io.IniFilename = g_imgui_ini;
    io.ConfigFlags |= ImGuiConfigFlags_NoMouseCursorChange;       /* only while the menu is open we own the cursor */
    g_font_vi_ok = load_fonts(io);
    setup_style();
    if (!ImGui_ImplWin32_Init(hwnd)) { ImGui::DestroyContext(); return false; }
    if (!ImGui_ImplDX11_Init(dev, ctx)) { ImGui_ImplWin32_Shutdown(); ImGui::DestroyContext(); return false; }
    g_orig_wndproc = (WNDPROC)SetWindowLongPtrW(hwnd, GWLP_WNDPROC, (LONG_PTR)hk_wndproc);
    g_hwnd = hwnd;
    g_dev = dev;
    g_ready = true;
    (void)sc;
    return true;
}

static void render_overlay(IDXGISwapChain *sc) {
    DXGI_SWAP_CHAIN_DESC desc;
    if (FAILED(sc->GetDesc(&desc)) || !desc.OutputWindow) return;
    if (desc.SampleDesc.Count > 1) return;                 /* never seen on Unity back buffers */

    CsGuard lock;
    ID3D11Device *dev = NULL;
    if (FAILED(sc->GetDevice(kIID_ID3D11Device, (void **)&dev)) || !dev) {
        gs_log("overlay: swap chain has no D3D11 device (game not using D3D11) - overlay disabled");
        InterlockedExchange(&g_failed, 1);
        return;
    }
    ID3D11DeviceContext *ctx = NULL;
    dev->GetImmediateContext(&ctx);
    if (!ctx) { dev->Release(); return; }

    /* the game recreated its device or window: rebuild the ImGui backends */
    if (g_ready && (dev != g_dev || desc.OutputWindow != g_hwnd)) {
        gs_log("overlay: device/window changed - re-initialising");
        shutdown_imgui();
    }
    if (!g_ready) {
        if (!init_imgui(sc, dev, ctx, desc.OutputWindow)) {
            gs_log("overlay: ImGui init failed - overlay disabled");
            InterlockedExchange(&g_failed, 1);
            ctx->Release(); dev->Release();
            return;
        }
        g_first_frame_tick = GetTickCount();
        gs_log("overlay: ImGui initialised (%ux%u, format %d, hwnd %p)", desc.BufferDesc.Width,
               desc.BufferDesc.Height, (int)desc.BufferDesc.Format, (void *)desc.OutputWindow);
        char flag[MAX_PATH], e[8];
        snprintf(flag, sizeof flag, "%s\\trainer_menu_open.flag", gs_dir());
        if ((GetEnvironmentVariableA("GS_MENU_AUTOOPEN", e, sizeof e) && e[0] == '1') || file_exists(flag))
            gs_overlay_set_menu_open(1);
    }

    ID3D11Texture2D *bb = NULL;
    if (FAILED(sc->GetBuffer(0, kIID_ID3D11Texture2D, (void **)&bb)) || !bb) { ctx->Release(); dev->Release(); return; }
    D3D11_TEXTURE2D_DESC td; bb->GetDesc(&td);
    ID3D11RenderTargetView *rtv = NULL;
    if (FAILED(dev->CreateRenderTargetView(bb, NULL, &rtv)) || !rtv) {
        D3D11_RENDER_TARGET_VIEW_DESC rd; memset(&rd, 0, sizeof rd);
        rd.Format = view_format(td.Format);
        rd.ViewDimension = D3D11_RTV_DIMENSION_TEXTURE2D;
        if (FAILED(dev->CreateRenderTargetView(bb, &rd, &rtv))) rtv = NULL;
    }
    bb->Release();
    if (!rtv) { ctx->Release(); dev->Release(); return; }

    /* menu open/close requests from the hotkey thread */
    if (InterlockedExchange(&g_menu_toggle_req, 0)) g_menu_open = !g_menu_open;
    static LONG prev_open = 0;
    ImGuiIO &io = ImGui::GetIO();
    if (g_menu_open != prev_open) {
        io.ClearInputKeys();
        io.ClearEventsQueue();
        if (g_menu_open) {
            io.ConfigFlags &= ~ImGuiConfigFlags_NoMouseCursorChange;
            io.MouseDrawCursor = true;
            ClipCursor(NULL);
        } else {
            io.MouseDrawCursor = false;
            io.ConfigFlags |= ImGuiConfigFlags_NoMouseCursorChange;
            ini_save();
        }
        prev_open = g_menu_open;
    }

    float sc_ui = (float)td.Height / 1080.0f;
    if (sc_ui < 0.85f) sc_ui = 0.85f;
    if (sc_ui > 2.5f) sc_ui = 2.5f;
    sc_ui *= g_user_scale;
    apply_scale(sc_ui);

    ImGui_ImplDX11_NewFrame();
    ImGui_ImplWin32_NewFrame();
    io.DisplaySize = ImVec2((float)td.Width, (float)td.Height);
    ImGui::NewFrame();

    GsSnapshot snap;
    gs_get_snapshot(&snap);
    if (g_menu_open) draw_menu(snap, sc_ui);
    else draw_hud(snap, sc_ui);
    draw_toast(sc_ui);

    ImGui::Render();

    ID3D11RenderTargetView *prev_rtv[D3D11_SIMULTANEOUS_RENDER_TARGET_COUNT] = {};
    ID3D11DepthStencilView *prev_dsv = NULL;
    ctx->OMGetRenderTargets(D3D11_SIMULTANEOUS_RENDER_TARGET_COUNT, prev_rtv, &prev_dsv);
    ctx->OMSetRenderTargets(1, &rtv, NULL);
    ImGui_ImplDX11_RenderDrawData(ImGui::GetDrawData());
    ctx->OMSetRenderTargets(D3D11_SIMULTANEOUS_RENDER_TARGET_COUNT, prev_rtv, prev_dsv);
    for (auto &r : prev_rtv) if (r) r->Release();
    if (prev_dsv) prev_dsv->Release();

    rtv->Release();
    ctx->Release();
    dev->Release();
    InterlockedIncrement(&g_frames);
}

static HRESULT STDMETHODCALLTYPE hk_present(IDXGISwapChain *sc, UINT sync, UINT flags) {
    if (!(flags & DXGI_PRESENT_TEST) && !g_failed) render_overlay(sc);
    return o_present(sc, sync, flags);
}

/* ------------------------------------------------------------------ hook setup */
static LRESULT CALLBACK dummy_proc(HWND h, UINT m, WPARAM w, LPARAM l) { return DefWindowProcA(h, m, w, l); }

static void *find_present_address(void) {
    HMODULE d3d = GetModuleHandleW(L"d3d11.dll");
    if (!d3d) return NULL;
    D3D11CreateDeviceAndSwapChainFn create = (D3D11CreateDeviceAndSwapChainFn)GetProcAddress(d3d, "D3D11CreateDeviceAndSwapChain");
    if (!create) return NULL;

    WNDCLASSEXA wc; memset(&wc, 0, sizeof wc);
    wc.cbSize = sizeof wc; wc.lpfnWndProc = dummy_proc; wc.hInstance = GetModuleHandleA(NULL);
    wc.lpszClassName = "GSTrainerDummyWnd";
    RegisterClassExA(&wc);
    HWND w = CreateWindowExA(0, wc.lpszClassName, "gs-dummy", WS_OVERLAPPED, 0, 0, 64, 64, NULL, NULL, wc.hInstance, NULL);
    if (!w) return NULL;

    DXGI_SWAP_CHAIN_DESC sd; memset(&sd, 0, sizeof sd);
    sd.BufferCount = 1;
    sd.BufferDesc.Width = 64; sd.BufferDesc.Height = 64;
    sd.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
    sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    sd.OutputWindow = w;
    sd.SampleDesc.Count = 1;
    sd.Windowed = TRUE;
    sd.SwapEffect = DXGI_SWAP_EFFECT_DISCARD;

    static const D3D_FEATURE_LEVEL levels[] = { D3D_FEATURE_LEVEL_11_0, D3D_FEATURE_LEVEL_10_1, D3D_FEATURE_LEVEL_10_0 };
    IDXGISwapChain *sc = NULL; ID3D11Device *dev = NULL; ID3D11DeviceContext *ctx = NULL; D3D_FEATURE_LEVEL got;
    HRESULT hr = create(NULL, D3D_DRIVER_TYPE_HARDWARE, NULL, 0, levels, 3, D3D11_SDK_VERSION, &sd, &sc, &dev, &got, &ctx);
    if (FAILED(hr))   /* e.g. a remote session: the WARP software rasteriser has the same vtable layout */
        hr = create(NULL, D3D_DRIVER_TYPE_WARP, NULL, 0, levels, 3, D3D11_SDK_VERSION, &sd, &sc, &dev, &got, &ctx);
    void *present = NULL;
    if (SUCCEEDED(hr) && sc) {
        void **vtbl = *(void ***)sc;
        present = vtbl[8];                                /* IDXGISwapChain::Present */
    } else {
        gs_log("overlay: dummy swap chain failed (hr=0x%08lX)", (unsigned long)hr);
    }
    if (sc) sc->Release();
    if (ctx) ctx->Release();
    if (dev) dev->Release();
    DestroyWindow(w);
    UnregisterClassA(wc.lpszClassName, wc.hInstance);
    return present;
}

static DWORD WINAPI overlay_thread(LPVOID p) {
    (void)p;
    for (int i = 0; i < 1200; i++) {                     /* up to ~5 min for the game to load d3d11/dxgi */
        if (GetModuleHandleW(L"d3d11.dll") && GetModuleHandleW(L"dxgi.dll")) break;
        Sleep(250);
    }
    if (!GetModuleHandleW(L"d3d11.dll")) { gs_log("overlay: d3d11.dll never loaded - overlay disabled"); return 0; }
    Sleep(1500);                                          /* let Unity create its own device first */

    void *present = find_present_address();
    if (!present) { gs_log("overlay: could not locate IDXGISwapChain::Present"); return 0; }
    if (MH_CreateHook(present, (void *)hk_present, (void **)&o_present) != MH_OK ||
        MH_EnableHook(present) != MH_OK) {
        gs_log("overlay: Present hook failed");
        return 0;
    }
    gs_log("overlay: Present hooked at %p", present);

    /* watchdog: tell the user in the log when nothing has been drawn */
    for (int i = 0; i < 120 && g_frames == 0 && !g_failed; i++) Sleep(500);
    if (g_frames == 0 && !g_failed)
        gs_log("overlay: no frame after 60 s (the game is probably not rendering with D3D11)");
    return 0;
}

extern "C" void gs_overlay_start(void) {
    InitializeCriticalSection(&g_toast_cs);
    InitializeCriticalSection(&g_imgui_cs);
    snprintf(g_ini, sizeof g_ini, "%s\\gs_trainer.ini", gs_dir());
    snprintf(g_imgui_ini, sizeof g_imgui_ini, "%s\\gs_trainer_ui.ini", gs_dir());
    ini_load();
    CreateThread(NULL, 0, overlay_thread, NULL, 0, NULL);
}
