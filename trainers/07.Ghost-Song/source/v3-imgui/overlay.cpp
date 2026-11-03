/*
 * Ghost Song Trainer v3 - in-game menu (Dear ImGui drawn on the game's own Direct3D 11 frame).
 *
 * A throw-away D3D11 device on a hidden window gives us the address of IDXGISwapChain::Present (vtable slot 8);
 * that function is detoured with MinHook.  Every frame the detour draws an ImGui frame onto the back buffer and then
 * calls the real Present.  The game window's WndProc is subclassed so mouse / keyboard go to ImGui while the menu is open.
 * The overlay never touches il2cpp objects: it reads the snapshot published by the game thread and flips feature flags.
 */
#include <windows.h>
#include <d3d11.h>
#include <d3dcompiler.h>
#include <dxgi.h>
#include <stdio.h>
#include <string.h>

#include "imgui.h"
#include "imgui_impl_win32.h"
#include "imgui_impl_dx11.h"
#include "MinHook.h"
#include "gs3.h"

extern IMGUI_IMPL_API LRESULT ImGui_ImplWin32_WndProcHandler(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);

/* ---- D3DCompile shim: do NOT import d3dcompiler_47.dll statically (a missing DLL would stop the game from starting) ---- */
extern "C" HRESULT WINAPI D3DCompile(LPCVOID src, SIZE_T size, LPCSTR name, const D3D_SHADER_MACRO *defs, ID3DInclude *inc,
                                     LPCSTR entry, LPCSTR target, UINT f1, UINT f2, ID3DBlob **code, ID3DBlob **err)
{
    typedef HRESULT(WINAPI * Fn)(LPCVOID, SIZE_T, LPCSTR, const D3D_SHADER_MACRO *, ID3DInclude *, LPCSTR, LPCSTR, UINT, UINT, ID3DBlob **, ID3DBlob **);
    static Fn fn;
    if (!fn) {
        HMODULE m = LoadLibraryA("d3dcompiler_47.dll");
        if (!m) m = LoadLibraryA("d3dcompiler_46.dll");
        if (!m) m = LoadLibraryA("d3dcompiler_43.dll");
        if (m) fn = (Fn)GetProcAddress(m, "D3DCompile");
    }
    return fn ? fn(src, size, name, defs, inc, entry, target, f1, f2, code, err) : E_FAIL;
}

/* ------------------------------------------------------------------ state */
typedef HRESULT(STDMETHODCALLTYPE *PresentFn)(IDXGISwapChain *, UINT, UINT);
typedef HRESULT(WINAPI *CreateDevSwapFn)(IDXGIAdapter *, D3D_DRIVER_TYPE, HMODULE, UINT, const D3D_FEATURE_LEVEL *, UINT, UINT,
                                         const DXGI_SWAP_CHAIN_DESC *, IDXGISwapChain **, ID3D11Device **, D3D_FEATURE_LEVEL *, ID3D11DeviceContext **);

static PresentFn          o_Present;
static WNDPROC            o_WndProc;
static HWND               g_hwnd;
static ID3D11Device      *g_dev;
static ID3D11DeviceContext *g_ctx;
static CRITICAL_SECTION   g_cs;
static volatile LONG      g_menu_open;
static volatile LONG      g_init_done, g_failed, g_hooked;
static volatile unsigned  g_frames;
static DWORD              g_start_tick;
static int                g_win_w, g_win_h;

extern "C" int gs3_overlay_menu_open(void) { return (int)g_menu_open; }
extern "C" void gs3_overlay_menu_toggle(void) { InterlockedExchange(&g_menu_open, g_menu_open ? 0 : 1); }
extern "C" unsigned gs3_overlay_frames(void) { return g_frames; }
extern "C" int gs3_overlay_status(void) { return g_failed ? HS_FAIL : (g_init_done && g_frames > 0 ? HS_OK : HS_NONE); }

/* ------------------------------------------------------------------ UI */
static void tip(const char *text)
{
    if (ImGui::IsItemHovered(ImGuiHoveredFlags_AllowWhenDisabled)) ImGui::SetTooltip("%s", text);
}

static void toggle_row(int id, const char *tooltip)
{
    bool on = gs3_feature_get(id) != 0;
    bool avail = gs3_feature_status(id) == HS_OK;
    char label[128];
    const char *key = gs3_feature_hotkey(id);
    if (key[0]) snprintf(label, sizeof label, "%s   [%s]##ft%d", gs3_feature_name(id), key, id);
    else        snprintf(label, sizeof label, "%s##ft%d", gs3_feature_name(id), id);
    ImGui::BeginDisabled(!avail);
    if (ImGui::Checkbox(label, &on)) gs3_feature_set(id, on ? 1 : 0);
    ImGui::EndDisabled();
    if (!avail) tip("Not available: the required game hook / field was not found.");
    else if (tooltip) tip(tooltip);
}

static void action_btn(int id, const char *tooltip)
{
    char label[128];
    const char *key = gs3_action_hotkey(id);
    if (key[0]) snprintf(label, sizeof label, "%s   [%s]##ac%d", gs3_action_name(id), key, id);
    else        snprintf(label, sizeof label, "%s##ac%d", gs3_action_name(id), id);
    bool avail = gs3_action_status(id) == HS_OK;
    ImGui::BeginDisabled(!avail);
    if (ImGui::Button(label)) gs3_action(id);
    ImGui::EndDisabled();
    if (tooltip) tip(tooltip);
}

static void build_menu(void)
{
    Gs3Snapshot s; gs3_get_snapshot(&s);
    ImGui::SetNextWindowPos(ImVec2(24, 24), ImGuiCond_FirstUseEver);
    ImGui::SetNextWindowBgAlpha(0.93f);
    if (!ImGui::Begin("Ghost Song Trainer " GS3_VERSION "   -   F10 / Insert = hide", nullptr, ImGuiWindowFlags_AlwaysAutoResize | ImGuiWindowFlags_NoCollapse)) { ImGui::End(); return; }

    if (s.valid) {
        ImGui::TextColored(ImVec4(0.55f, 0.95f, 0.65f, 1), "HP %.0f/%.0f   Spirit %.0f/%.0f   Stamina %.0f/%.0f", (double)s.hp, (double)s.hpmax, (double)s.spirit, (double)s.spiritmax, (double)s.stamina, (double)s.staminamax);
        ImGui::TextColored(ImVec4(0.95f, 0.85f, 0.45f, 1), "Nanogel %d   Bugblood %d   Heal cores %d   Ammo %.0f/%.0f", s.nanites, s.blood, s.heals, (double)s.ammo, (double)s.ammomax);
    } else {
        ImGui::TextColored(ImVec4(1, 0.7f, 0.4f, 1), "Waiting for a running game - load a save.");
    }
    ImGui::Separator();

    if (ImGui::CollapsingHeader("Survival", ImGuiTreeNodeFlags_DefaultOpen)) {
        toggle_row(FT_GOD, "No damage and cannot die (hook on the player's TakeDamage + health pinned + isImmortal).");
        action_btn(AC_HEAL, "Full restore with the game's own status.rest() (health, spirit, ammo, heal fuel, stamina).");
        toggle_row(FT_STAMINA, "Stamina and spirit (mana) always full.");
        toggle_row(FT_AMMO, "Ammo always full, the gun never overheats.");
    }
    if (ImGui::CollapsingHeader("Economy and items", ImGuiTreeNodeFlags_DefaultOpen)) {
        action_btn(AC_ADDMONEY, "Adds the amount below to Nanogel (the shop currency).");
        ImGui::SameLine();
        ImGui::SetNextItemWidth(150 * ImGui::GetIO().FontGlobalScale);
        if (ImGui::InputInt("##amt", &g_set.money_amount, 10000, 100000)) { if (g_set.money_amount < 1) g_set.money_amount = 1; if (g_set.money_amount > 1000000000) g_set.money_amount = 1000000000; }
        if (ImGui::IsItemDeactivatedAfterEdit()) gs3_settings_save();
        if (ImGui::SmallButton("10k")) { g_set.money_amount = 10000; gs3_settings_save(); }
        ImGui::SameLine(); if (ImGui::SmallButton("100k")) { g_set.money_amount = 100000; gs3_settings_save(); }
        ImGui::SameLine(); if (ImGui::SmallButton("1M")) { g_set.money_amount = 1000000; gs3_settings_save(); }
        ImGui::SameLine(); if (ImGui::SmallButton("10M")) { g_set.money_amount = 10000000; gs3_settings_save(); }
        ImGui::Spacing();
        toggle_row(FT_MONEY, "Keeps Nanogel (and Bugblood) topped up, so every shop / upgrade / repair is free. [F3 toggles money + items]");
        toggle_row(FT_ITEMS, "Keeps consumables stocked (ammo clusters, nanogel clusters, nuggets, leg brace), heal fuel and ammo full. [F3]");
        toggle_row(FT_SEEDS, "Also keeps the seeds / fruit that give PERMANENT stats at 25 - using them raises your saved stats.");
        ImGui::Spacing();
        action_btn(AC_GIVEALL, "Abilities, weapons, modules and 10 healing cores through the game's own methods. CHANGES YOUR SAVE. Press twice.");
        if (gs3_giveall_busy()) { ImGui::SameLine(); ImGui::TextDisabled("giving ..."); }
    }
    if (ImGui::CollapsingHeader("Movement", ImGuiTreeNodeFlags_DefaultOpen)) {
        toggle_row(FT_JUMP, "Unlimited mid-air jumps (hook on playermovement.Jump; nothing is written permanently).");
        toggle_row(FT_SPEED, "Multiplies the player's top run speed (ground and air).");
        ImGui::SetNextItemWidth(220 * ImGui::GetIO().FontGlobalScale);
        ImGui::SliderFloat("##spd", &g_set.speed_mult, 1.0f, 4.0f, "speed x%.2f");
        if (ImGui::IsItemDeactivatedAfterEdit()) gs3_settings_save();
    }
    if (ImGui::CollapsingHeader("Combat", ImGuiTreeNodeFlags_DefaultOpen)) {
        toggle_row(FT_OHK, "Every hit on an enemy becomes lethal (immune parts stay immune; bosses may skip phases).");
    }
    if (ImGui::CollapsingHeader("World", ImGuiTreeNodeFlags_DefaultOpen)) {
        toggle_row(FT_MAPALL, "While ON, opening the map shows every area, every pickup icon and every save / big-bot icon. Nothing is saved.");
        action_btn(AC_UNLOCKMAP, "Marks every map chunk as owned (written to your save).");
    }
    if (ImGui::CollapsingHeader("Settings")) {
        ImGui::SetNextItemWidth(220 * ImGui::GetIO().FontGlobalScale);
        ImGui::SliderFloat("Menu scale", &g_set.ui_scale, 0.7f, 2.0f, "%.2f");
        if (ImGui::IsItemDeactivatedAfterEdit()) gs3_settings_save();
        bool strip = g_set.hud_strip != 0;
        if (ImGui::Checkbox("Show active cheats while the menu is closed", &strip)) { g_set.hud_strip = strip ? 1 : 0; gs3_settings_save(); }
        ImGui::SetNextItemWidth(160 * ImGui::GetIO().FontGlobalScale);
        ImGui::InputInt("Unlimited-money level", &g_set.money_target, 1000000, 10000000);
        if (g_set.money_target < 1000) g_set.money_target = 1000;
        if (g_set.money_target > 2000000000) g_set.money_target = 2000000000;
        if (ImGui::IsItemDeactivatedAfterEdit()) gs3_settings_save();
        action_btn(AC_DIAG, "Writes hooks, counters, stats and the inventory table to gs3_trainer.log.");
        ImGui::TextDisabled("Hotkeys work while the game window is focused.");
    }
    ImGui::End();
}

static void build_hud(void)
{
    ImDrawList *dl = ImGui::GetForegroundDrawList();
    ImVec2 disp = ImGui::GetIO().DisplaySize;
    float fs = ImGui::GetFontSize();
    char toast[160];
    int rem = gs3_toast_get(toast, sizeof toast);
    if (rem > 0) {
        ImVec2 sz = ImGui::CalcTextSize(toast);
        float a = rem < 500 ? rem / 500.0f : 1.0f;
        ImVec2 p((disp.x - sz.x) * 0.5f, disp.y * 0.08f);
        dl->AddRectFilled(ImVec2(p.x - 12, p.y - 6), ImVec2(p.x + sz.x + 12, p.y + sz.y + 6), IM_COL32(15, 20, 28, (int)(215 * a)), 6.0f);
        dl->AddText(p, IM_COL32(255, 240, 190, (int)(255 * a)), toast);
    }
    if (!gs3_overlay_menu_open()) {
        float y = 8;
        if (GetTickCount() - g_start_tick < 15000) {
            dl->AddText(ImVec2(10, y), IM_COL32(190, 220, 255, 230), "Ghost Song Trainer " GS3_VERSION "  -  F10 / Insert = menu"); y += fs + 2;
        }
        if (g_set.hud_strip) {
            for (int i = 0; i < FT__COUNT; i++) {
                if (!gs3_feature_get(i)) continue;
                char t[96];
                if (i == FT_SPEED) snprintf(t, sizeof t, "%s x%.2g", gs3_feature_name(i), (double)g_set.speed_mult);
                else snprintf(t, sizeof t, "%s", gs3_feature_name(i));
                dl->AddText(ImVec2(11, y + 1), IM_COL32(0, 0, 0, 200), t);
                dl->AddText(ImVec2(10, y), IM_COL32(120, 255, 150, 235), t);
                y += fs + 1;
            }
        }
    }
}

/* ------------------------------------------------------------------ input */
static bool is_mouse_msg(UINT m)
{
    return (m >= WM_MOUSEFIRST && m <= WM_MOUSELAST) || (m >= WM_NCMOUSEMOVE && m <= WM_NCMBUTTONDBLCLK) || m == WM_MOUSEHWHEEL;
}

static LRESULT CALLBACK hk_WndProc(HWND h, UINT m, WPARAM w, LPARAM l)
{
    if (g_init_done && g_menu_open) {
        EnterCriticalSection(&g_cs);
        ImGui_ImplWin32_WndProcHandler(h, m, w, l);
        LeaveCriticalSection(&g_cs);
        if (is_mouse_msg(m)) return 0;                              /* the game must not see clicks meant for the menu */
        if (m == WM_INPUT) return DefWindowProcW(h, m, w, l);       /* raw input -> cleanup only */
        if (m == WM_KEYDOWN || m == WM_CHAR || m == WM_SYSCHAR) return 0;
    }
    return CallWindowProcW(o_WndProc, h, m, w, l);
}

/* ------------------------------------------------------------------ frame */
static bool init_imgui(IDXGISwapChain *sc)
{
    if (FAILED(sc->GetDevice(__uuidof(ID3D11Device), (void **)&g_dev)) || !g_dev) return false;
    g_dev->GetImmediateContext(&g_ctx);
    DXGI_SWAP_CHAIN_DESC d; if (FAILED(sc->GetDesc(&d))) return false;
    g_hwnd = d.OutputWindow;
    if (!g_hwnd || !g_ctx) return false;

    ImGui::CreateContext();
    ImGuiIO &io = ImGui::GetIO();
    io.IniFilename = nullptr;
    io.LogFilename = nullptr;
    ImFont *f = io.Fonts->AddFontFromFileTTF("C:\\Windows\\Fonts\\segoeui.ttf", 18.0f);
    if (!f) io.Fonts->AddFontDefault();
    ImGui::StyleColorsDark();
    ImGuiStyle &st = ImGui::GetStyle();
    st.WindowRounding = 7; st.FrameRounding = 4; st.GrabRounding = 4; st.WindowBorderSize = 1; st.ItemSpacing = ImVec2(8, 6);
    st.Colors[ImGuiCol_WindowBg] = ImVec4(0.07f, 0.09f, 0.12f, 0.94f);
    st.Colors[ImGuiCol_CheckMark] = ImVec4(0.45f, 0.95f, 0.55f, 1);
    st.Colors[ImGuiCol_TitleBgActive] = ImVec4(0.12f, 0.30f, 0.30f, 1);
    st.Colors[ImGuiCol_Header] = ImVec4(0.14f, 0.34f, 0.34f, 0.8f);

    if (!ImGui_ImplWin32_Init(g_hwnd)) return false;
    if (!ImGui_ImplDX11_Init(g_dev, g_ctx)) return false;
    o_WndProc = (WNDPROC)SetWindowLongPtrW(g_hwnd, GWLP_WNDPROC, (LONG_PTR)hk_WndProc);
    g_win_w = (int)d.BufferDesc.Width; g_win_h = (int)d.BufferDesc.Height;
    gs3_log("overlay: ImGui initialised (%dx%d, hwnd %p)", g_win_w, g_win_h, (void *)g_hwnd);
    return true;
}

static void draw_frame(IDXGISwapChain *sc)
{
    if (g_failed) return;
    EnterCriticalSection(&g_cs);
    if (!g_init_done) {
        if (!init_imgui(sc)) { InterlockedExchange(&g_failed, 1); gs3_log("overlay: init failed - menu disabled (hotkeys still work)"); LeaveCriticalSection(&g_cs); return; }
        InterlockedExchange(&g_init_done, 1);
        g_start_tick = GetTickCount();
    }
    ID3D11Texture2D *bb = nullptr;
    ID3D11RenderTargetView *rtv = nullptr;
    if (SUCCEEDED(sc->GetBuffer(0, __uuidof(ID3D11Texture2D), (void **)&bb)) && bb) {
        g_dev->CreateRenderTargetView(bb, nullptr, &rtv);
        bb->Release();
    }
    if (rtv) {
        ImGuiIO &io = ImGui::GetIO();
        RECT rc; GetClientRect(g_hwnd, &rc);
        float h = (float)(rc.bottom - rc.top);
        float base = h / 1080.0f; if (base < 0.8f) base = 0.8f; if (base > 2.5f) base = 2.5f;
        io.FontGlobalScale = base * g_set.ui_scale;
        io.MouseDrawCursor = g_menu_open != 0;
        ImGui_ImplDX11_NewFrame();
        ImGui_ImplWin32_NewFrame();
        ImGui::NewFrame();
        if (g_menu_open) build_menu();
        build_hud();
        ImGui::Render();
        g_ctx->OMSetRenderTargets(1, &rtv, nullptr);
        ImGui_ImplDX11_RenderDrawData(ImGui::GetDrawData());
        rtv->Release();
        g_frames++;
    }
    LeaveCriticalSection(&g_cs);
}

static HRESULT STDMETHODCALLTYPE hk_Present(IDXGISwapChain *sc, UINT sync, UINT flags)
{
    if (!(flags & DXGI_PRESENT_TEST)) draw_frame(sc);
    return o_Present(sc, sync, flags);
}

/* ------------------------------------------------------------------ hooking */
static void *find_present(void)
{
    WNDCLASSA wc = {}; wc.lpfnWndProc = DefWindowProcA; wc.hInstance = GetModuleHandleA(nullptr); wc.lpszClassName = "GS3DummyWnd";
    RegisterClassA(&wc);
    HWND hw = CreateWindowExA(0, wc.lpszClassName, "gs3", WS_OVERLAPPEDWINDOW, 0, 0, 64, 64, nullptr, nullptr, wc.hInstance, nullptr);
    void *present = nullptr;
    HMODULE d3d = GetModuleHandleA("d3d11.dll");
    CreateDevSwapFn create = d3d ? (CreateDevSwapFn)GetProcAddress(d3d, "D3D11CreateDeviceAndSwapChain") : nullptr;
    if (hw && create) {
        DXGI_SWAP_CHAIN_DESC sd = {};
        sd.BufferCount = 1; sd.BufferDesc.Width = 64; sd.BufferDesc.Height = 64; sd.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
        sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT; sd.OutputWindow = hw; sd.SampleDesc.Count = 1; sd.Windowed = TRUE; sd.SwapEffect = DXGI_SWAP_EFFECT_DISCARD;
        const D3D_FEATURE_LEVEL fl[] = { D3D_FEATURE_LEVEL_11_0, D3D_FEATURE_LEVEL_10_1, D3D_FEATURE_LEVEL_10_0 };
        IDXGISwapChain *sc = nullptr; ID3D11Device *dev = nullptr; ID3D11DeviceContext *ctx = nullptr; D3D_FEATURE_LEVEL got;
        HRESULT hr = create(nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr, 0, fl, 3, D3D11_SDK_VERSION, &sd, &sc, &dev, &got, &ctx);
        if (FAILED(hr)) hr = create(nullptr, D3D_DRIVER_TYPE_WARP, nullptr, 0, fl, 3, D3D11_SDK_VERSION, &sd, &sc, &dev, &got, &ctx);
        if (SUCCEEDED(hr) && sc) {
            present = (*(void ***)sc)[8];
            sc->Release(); dev->Release(); ctx->Release();
        } else gs3_log("overlay: dummy D3D11 device failed (0x%08lX)", (unsigned long)hr);
    }
    if (hw) DestroyWindow(hw);
    UnregisterClassA(wc.lpszClassName, wc.hInstance);
    return present;
}

static DWORD WINAPI overlay_thread(LPVOID)
{
    for (int i = 0; i < 1200 && !(GetModuleHandleA("d3d11.dll") && GetModuleHandleA("dxgi.dll")); i++) Sleep(100);
    if (!GetModuleHandleA("d3d11.dll")) { gs3_log("overlay: game does not use Direct3D 11 - menu disabled (hotkeys still work)"); InterlockedExchange(&g_failed, 1); return 0; }
    Sleep(2500);                                      /* let Unity create its own device first */
    void *present = find_present();
    if (!present) { InterlockedExchange(&g_failed, 1); return 0; }
    if (MH_CreateHook(present, (void *)hk_Present, (void **)&o_Present) != MH_OK || MH_EnableHook(present) != MH_OK) {
        gs3_log("overlay: hooking Present failed"); InterlockedExchange(&g_failed, 1); return 0;
    }
    InterlockedExchange(&g_hooked, 1);
    gs3_log("overlay: Present hooked at %p", present);
    return 0;
}

extern "C" void gs3_overlay_start(void)
{
    InitializeCriticalSection(&g_cs);
    CreateThread(nullptr, 0, overlay_thread, nullptr, 0, nullptr);
}
