/*
 * version.dll proxy: every export is a naked `jmp` through a table filled from the real system32\version.dll.
 * This file deliberately does NOT include <windows.h>: <winver.h> declares the same exports with real prototypes.
 */
#include <stddef.h>

typedef void *HMODULE_;
typedef unsigned short WCHAR_;
__declspec(dllimport) unsigned int __stdcall GetSystemDirectoryW(WCHAR_ *buf, unsigned int size);
__declspec(dllimport) HMODULE_ __stdcall LoadLibraryW(const WCHAR_ *name);
__declspec(dllimport) void *__stdcall GetProcAddress(HMODULE_ mod, const char *name);

#define VER_EXPORTS(X) \
    X(GetFileVersionInfoA) X(GetFileVersionInfoByHandle) X(GetFileVersionInfoExA) X(GetFileVersionInfoExW) \
    X(GetFileVersionInfoSizeA) X(GetFileVersionInfoSizeExA) X(GetFileVersionInfoSizeExW) X(GetFileVersionInfoSizeW) \
    X(GetFileVersionInfoW) X(VerFindFileA) X(VerFindFileW) X(VerInstallFileA) X(VerInstallFileW) \
    X(VerLanguageNameA) X(VerLanguageNameW) X(VerQueryValueA) X(VerQueryValueW)

enum {
#define X(n) FWDIDX_##n,
    VER_EXPORTS(X)
#undef X
    FWD__COUNT
};

__attribute__((used)) void *g_real[FWD__COUNT];

#define X(n) \
    __attribute__((naked)) void n(void) { __asm__ volatile("jmpq *g_real+%c0*8(%%rip)" : : "i"(FWDIDX_##n)); }
VER_EXPORTS(X)
#undef X

static const char *const k_fwd_names[FWD__COUNT] = {
#define X(n) #n,
    VER_EXPORTS(X)
#undef X
};

void proxy_load_real(void)
{
    WCHAR_ path[300];
    unsigned int n = GetSystemDirectoryW(path, 260);
    if (n == 0 || n > 240) return;
    static const WCHAR_ tail[] = { '\\', 'v', 'e', 'r', 's', 'i', 'o', 'n', '.', 'd', 'l', 'l', 0 };
    for (size_t i = 0; i < sizeof tail / sizeof tail[0]; i++) path[n + i] = tail[i];
    HMODULE_ h = LoadLibraryW(path);
    if (!h) return;
    for (int i = 0; i < FWD__COUNT; i++) g_real[i] = GetProcAddress(h, k_fwd_names[i]);
}
