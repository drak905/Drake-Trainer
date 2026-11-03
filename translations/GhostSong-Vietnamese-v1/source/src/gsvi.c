/*
 *  Ghost Song - Vietnamese language pack  (winmm.dll proxy, Unity 2020.3.36f1 IL2CPP x64)
 *
 *  Ghost Song already contains a 9th language slot that the shipped game never exposes:
 *    - LocalizationManager.languages = [English, Spanish, French, German, Japanese, Chinese, Russian, Korean, Portuguese]
 *    - UItexty.processlanguage has a `case 8` ("Portugues") and the save key "languagechoice" can hold 8
 *    - the language row of the settings menu (settingsfabio.Update) stops at 7 (Korean):   if (choice < 7) choice++ else choice = -1
 *  This pack turns that dormant slot (index 8) into **Tieng Viet**:
 *
 *   1. MENU       two 1-byte patches in settingsfabio.Update make the language row cycle ... Korean -> Viet -> Auto-detect
 *                 (cmp edi,7 -> cmp edi,8   and   LanguageChoice = 7 -> 8 on the wrap-around).
 *   2. DIALOGUE   hook LocalizationData.GetValueByCode: for the slot whose SystemLanguage is Portuguese (28) the
 *                 answer comes from vi_dlg.tsv (CODE -> Vietnamese) instead of Resources/Localization/Portuguese.
 *   3. UI TEXT    hook UItexty.processlanguage: after the game ran its (Portuguese) case 8, every public UI string field
 *                 listed in vi_ui.tsv is overwritten with the Vietnamese text (looked up BY NAME through the il2cpp API).
 *   4. FONT       none needed: the game's ShareTech font falls back to NotoSans/NotoSansJP which already contain every
 *                 Vietnamese letter (verified with fontTools).
 *
 *  Nothing in the game folder is modified.  The DLL forwards all 181 winmm.dll exports to the real system DLL.
 *  A build guard compares the prologue of every hook target and the bytes around every patch with the reference build
 *  (GameAssembly.dll SHA-256 43A0C121...6246); on a mismatch that part is skipped instead of crashing.
 */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdarg.h>

#include "gsvi_il2cpp.h"
#include "MinHook.h"

/* ------------------------------------------------------------------ reference build */
#define RVA_GETVALUE    0x1183B10ull   /* LocalizationData.GetValueByCode(string code, string def, string column) */
#define RVA_PROCLANG    0x11F8ED0ull   /* UItexty.processlanguage(int)                                            */
#define RVA_MENU_CMP    0x11ECA75ull   /* settingsfabio.Update:  83 FF 07 7C 4B    cmp edi,7 ; jl                  */
#define RVA_MENU_WRAP   0x11EC9D9ull   /* settingsfabio.Update:  C7 40 20 07 00 00 00   mov [rax+0x20],7            */

static const unsigned char SIG_GETVALUE[] = { 0x48, 0x89, 0x5C, 0x24, 0x08, 0x48, 0x89, 0x6C, 0x24, 0x10, 0x48, 0x89, 0x74, 0x24, 0x18, 0x57, 0x48, 0x83, 0xEC, 0x20 };
static const unsigned char SIG_PROCLANG[] = { 0x48, 0x89, 0x5C, 0x24, 0x10, 0x57, 0x48, 0x83, 0xEC, 0x20, 0x80, 0x3D };
static const unsigned char CTX_MENU_CMP[]  = { 0x83, 0xFF, 0x07, 0x7C, 0x4B };
static const unsigned char CTX_MENU_WRAP[] = { 0xC7, 0x40, 0x20, 0x07, 0x00, 0x00, 0x00 };

#define VI_SLOT_LANGUAGE 28      /* UnityEngine.SystemLanguage.Portuguese - the dormant 9th slot */
#define VI_SLOT_CHOICE   8       /* LanguageStuff.LanguageChoice value of that slot               */
#define OFF_LOCDATA_LANG 0x10    /* LocalizationData.language                                     */

/* ------------------------------------------------------------------ state */
static char g_dir[MAX_PATH], g_datadir[MAX_PATH], g_logpath[MAX_PATH];
static volatile LONG g_hooks_ok, g_patches_ok, g_dlg_hits, g_dlg_miss, g_ui_applied, g_ui_fields_set, g_ui_fields_missing;
static volatile LONG g_proclang_calls;
static void *volatile g_uit_any;                 /* a live UItexty instance (captured in the hook) */
static void *volatile g_proclang_mi;
static volatile LONG g_last_lang = -2;

static void logf_(const char *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    FILE *f = fopen(g_logpath, "a");
    if (f) { vfprintf(f, fmt, ap); fputc('\n', f); fclose(f); }
    va_end(ap);
}

/* ------------------------------------------------------------------ tables */
typedef struct {
    wchar_t *key;  uint32_t klen;
    wchar_t *val;  uint32_t vlen;
    uint32_t hash;
    uint32_t handle;            /* il2cpp GC handle of the cached managed string (0 = none) */
    Il2CppFieldInfo *field;     /* UI table: resolved field */
    int32_t foff;               /* UI table: field offset (-1 = not found) */
} Entry;

typedef struct {
    Entry *items; uint32_t count;
    uint32_t *slots; uint32_t mask;
    wchar_t *buf;
} Table;

static Table g_dlg, g_ui;

static uint32_t fnv(const uint16_t *s, uint32_t n) {
    uint32_t h = 2166136261u;
    for (uint32_t i = 0; i < n; i++) { h ^= s[i]; h *= 16777619u; }
    return h;
}

/* in-place un-escape: \\ -> \ , \t -> TAB , \n -> LF , \r -> CR ; returns new length */
static uint32_t unescape_w(wchar_t *s, uint32_t n) {
    uint32_t o = 0;
    for (uint32_t i = 0; i < n; i++) {
        wchar_t c = s[i];
        if (c == L'\\' && i + 1 < n) {
            wchar_t d = s[i + 1];
            if (d == L'n') { s[o++] = L'\n'; i++; continue; }
            if (d == L't') { s[o++] = L'\t'; i++; continue; }
            if (d == L'r') { s[o++] = L'\r'; i++; continue; }
            if (d == L'\\') { s[o++] = L'\\'; i++; continue; }
        }
        s[o++] = c;
    }
    s[o] = 0;
    return o;
}

static int table_load(Table *t, const char *path) {
    memset(t, 0, sizeof *t);
    HANDLE h = CreateFileA(path, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (h == INVALID_HANDLE_VALUE) { logf_("cannot open %s (err %lu)", path, GetLastError()); return 0; }
    DWORD sz = GetFileSize(h, NULL), rd = 0;
    char *raw = (char *)malloc(sz + 1);
    if (!raw || !ReadFile(h, raw, sz, &rd, NULL) || rd != sz) { CloseHandle(h); free(raw); return 0; }
    CloseHandle(h);
    char *p = raw; DWORD n = sz;
    if (n >= 3 && (unsigned char)p[0] == 0xEF && (unsigned char)p[1] == 0xBB && (unsigned char)p[2] == 0xBF) { p += 3; n -= 3; }
    int wn = MultiByteToWideChar(CP_UTF8, 0, p, (int)n, NULL, 0);
    wchar_t *w = (wchar_t *)malloc(((size_t)wn + 2) * sizeof(wchar_t));
    if (!w) { free(raw); return 0; }
    MultiByteToWideChar(CP_UTF8, 0, p, (int)n, w, wn);
    w[wn] = 0;
    free(raw);

    uint32_t lines = 0;
    for (int i = 0; i < wn; i++) if (w[i] == L'\n') lines++;
    lines++;
    t->items = (Entry *)calloc(lines, sizeof(Entry));
    t->buf = w;
    int i = 0;
    while (i < wn) {
        int ls = i;
        while (i < wn && w[i] != L'\n') i++;
        int le = i;                     /* line is [ls, le) */
        if (i < wn) i++;
        if (le > ls && w[le - 1] == L'\r') le--;
        if (le <= ls) continue;
        int tab = -1;
        for (int k = ls; k < le; k++) if (w[k] == L'\t') { tab = k; break; }
        if (tab < 0) continue;
        w[tab] = 0; w[le] = 0;          /* le may be the '\n' / end: safe because buffer has +2 spare and '\n' is consumed */
        Entry *e = &t->items[t->count];
        e->key = w + ls;      e->klen = unescape_w(e->key, (uint32_t)(tab - ls));
        e->val = w + tab + 1; e->vlen = unescape_w(e->val, (uint32_t)(le - tab - 1));
        e->hash = fnv((const uint16_t *)e->key, e->klen);
        e->foff = -2;
        t->count++;
    }
    uint32_t sizep = 16;
    while (sizep < t->count * 2) sizep <<= 1;
    t->slots = (uint32_t *)calloc(sizep, sizeof(uint32_t));
    t->mask = sizep - 1;
    uint32_t dup = 0;
    for (uint32_t k = 0; k < t->count; k++) {
        uint32_t s = t->items[k].hash & t->mask;
        int skip = 0;
        while (t->slots[s]) {
            Entry *o = &t->items[t->slots[s] - 1];
            if (o->hash == t->items[k].hash && o->klen == t->items[k].klen && memcmp(o->key, t->items[k].key, o->klen * 2) == 0) { skip = 1; break; }
            s = (s + 1) & t->mask;
        }
        if (skip) { dup++; continue; }            /* first occurrence wins (same rule as CSVObject.GetDataByCode) */
        t->slots[s] = k + 1;
    }
    logf_("loaded %s: %u entries (%u duplicate keys ignored)", path, t->count, dup);
    return 1;
}

static Entry *table_find(Table *t, const uint16_t *chars, uint32_t len) {
    if (!t->slots) return NULL;
    uint32_t h = fnv(chars, len);
    uint32_t s = h & t->mask;
    while (t->slots[s]) {
        Entry *e = &t->items[t->slots[s] - 1];
        if (e->hash == h && e->klen == len && memcmp(e->key, chars, (size_t)len * 2) == 0) return e;
        s = (s + 1) & t->mask;
    }
    return NULL;
}

/* managed string for an entry, cached behind a strong GC handle so it is created only once */
static Il2CppString *entry_string(Entry *e) {
    if (e->handle) {
        Il2CppObject *o = il2cpp_gchandle_get_target(e->handle);
        if (o) return (Il2CppString *)o;
    }
    Il2CppString *s = il2cpp_string_new_utf16((const uint16_t *)e->val, (int32_t)e->vlen);
    if (s) e->handle = il2cpp_gchandle_new((Il2CppObject *)s, 0);
    return s;
}

/* ------------------------------------------------------------------ hook: LocalizationData.GetValueByCode */
typedef Il2CppString *(__fastcall *FnGetValue)(void *self, Il2CppString *code, Il2CppString *def, Il2CppString *col, void *mi);
static FnGetValue o_getvalue;
static FnGetValue g_getvalue_target;

static Il2CppString *__fastcall hk_getvalue(void *self, Il2CppString *code, Il2CppString *def, Il2CppString *col, void *mi) {
    if (self && g_dlg.count && *(volatile int32_t *)((char *)self + OFF_LOCDATA_LANG) == VI_SLOT_LANGUAGE) {
        int content = 1;
        if (col) {
            int32_t cl = il2cpp_string_length(col);
            const uint16_t *cc = il2cpp_string_chars(col);
            content = (cl == 7 && cc[0] == 'C' && cc[1] == 'O' && cc[2] == 'N' && cc[3] == 'T' && cc[4] == 'E' && cc[5] == 'N' && cc[6] == 'T');
        }
        if (content && code) {
            Entry *e = table_find(&g_dlg, il2cpp_string_chars(code), (uint32_t)il2cpp_string_length(code));
            if (e) {
                Il2CppString *s = entry_string(e);
                if (s) { InterlockedIncrement(&g_dlg_hits); return s; }
            }
            LONG m = InterlockedIncrement(&g_dlg_miss);
            if (m <= 20) {
                char nm[256]; int l = il2cpp_string_length(code); if (l > 120) l = 120;
                int nb = WideCharToMultiByte(CP_UTF8, 0, (const wchar_t *)il2cpp_string_chars(code), l, nm, (int)sizeof nm - 1, NULL, NULL);
                nm[nb > 0 ? nb : 0] = 0;
                logf_("dlg miss #%ld: code='%s'", m, nm);
            }
            return def;                 /* exactly what the game does for an unknown code */
        }
    }
    return o_getvalue(self, code, def, col, mi);
}

/* ------------------------------------------------------------------ hook: UItexty.processlanguage */
typedef void (__fastcall *FnProcLang)(void *self, int32_t lang, void *mi);
static FnProcLang o_proclang;

static Il2CppFieldInfo *find_field(Il2CppClass *cls, const char *name) { return il2cpp_class_get_field_from_name(cls, name); }

/* write every Vietnamese UI string into the UItexty instance; returns number of fields set */
static int apply_ui(void *self, int *missing) {
    int set = 0, miss = 0;
    Il2CppClass *cls = il2cpp_object_get_class((Il2CppObject *)self);
    for (uint32_t i = 0; i < g_ui.count; i++) {
        Entry *e = &g_ui.items[i];
        if (e->foff == -2) {
            char nm[128];
            WideCharToMultiByte(CP_UTF8, 0, e->key, (int)e->klen, nm, sizeof nm - 1, NULL, NULL);
            nm[e->klen < sizeof nm - 1 ? e->klen : sizeof nm - 1] = 0;
            e->field = find_field(cls, nm);
            e->foff = e->field ? (int32_t)il2cpp_field_get_offset(e->field) : -1;
            if (e->foff < 0) logf_("UItexty has no field '%s'", nm);
        }
        if (e->foff < 0) { miss++; continue; }
        Il2CppString *s = entry_string(e);
        if (!s) { miss++; continue; }
        void **slot = (void **)((char *)self + e->foff);
        *slot = s;
        il2cpp_gc_wbarrier_set_field((Il2CppObject *)self, slot, s);
        set++;
    }
    if (missing) *missing = miss;
    return set;
}

static void __fastcall hk_proclang(void *self, int32_t lang, void *mi) {
    o_proclang(self, lang, mi);
    InterlockedIncrement(&g_proclang_calls);
    g_proclang_mi = mi;
    if (self) g_uit_any = self;
    InterlockedExchange(&g_last_lang, lang);
    if (lang == VI_SLOT_CHOICE && g_ui.count && self) {
        int miss = 0;
        int set = apply_ui(self, &miss);
        InterlockedExchange(&g_ui_fields_set, set);
        InterlockedExchange(&g_ui_fields_missing, miss);
        InterlockedIncrement(&g_ui_applied);
        logf_("Vietnamese UI applied: %d fields set, %d missing", set, miss);
    }
}

/* ------------------------------------------------------------------ patches / hooks */
static int bytes_equal(const unsigned char *p, const unsigned char *sig, size_t n) {
    MEMORY_BASIC_INFORMATION mbi;
    if (VirtualQuery(p, &mbi, sizeof mbi) == 0 || mbi.State != MEM_COMMIT) return 0;
    return memcmp(p, sig, n) == 0;
}

/* patch one immediate byte (07 -> 08) after verifying the surrounding instruction bytes */
static int patch_imm(unsigned char *base, unsigned long long rva, const unsigned char *ctx, size_t ctxlen, size_t immoff, const char *what) {
    unsigned char *p = base + rva;
    if (p[immoff] == 0x08 && memcmp(p, ctx, immoff) == 0) { logf_("patch %s: already applied", what); return 1; }
    if (!bytes_equal(p, ctx, ctxlen)) { logf_("build mismatch: %s context differs - patch skipped", what); return 0; }
    DWORD old;
    if (!VirtualProtect(p + immoff, 1, PAGE_EXECUTE_READWRITE, &old)) { logf_("VirtualProtect failed for %s", what); return 0; }
    p[immoff] = 0x08;
    VirtualProtect(p + immoff, 1, old, &old);
    FlushInstructionCache(GetCurrentProcess(), p, ctxlen);
    logf_("patch %s: 07 -> 08 at GameAssembly+0x%llX", what, rva + immoff);
    return 1;
}

static void install_all(int do_patches) {
    HMODULE ga = GetModuleHandleW(L"GameAssembly.dll");
    unsigned char *base = (unsigned char *)ga;
    LONG hooks = 0, patches = 0;
    if (MH_Initialize() != MH_OK) { logf_("MH_Initialize failed"); return; }

    void *p = base + RVA_GETVALUE;
    if (!bytes_equal(base + RVA_GETVALUE, SIG_GETVALUE, sizeof SIG_GETVALUE)) logf_("build mismatch: LocalizationData.GetValueByCode prologue differs - hook skipped");
    else if (MH_CreateHook(p, (void *)hk_getvalue, (void **)&o_getvalue) == MH_OK && MH_EnableHook(p) == MH_OK) { hooks++; g_getvalue_target = (FnGetValue)p; }
    else logf_("hook GetValueByCode failed");

    p = base + RVA_PROCLANG;
    if (!bytes_equal(base + RVA_PROCLANG, SIG_PROCLANG, sizeof SIG_PROCLANG)) logf_("build mismatch: UItexty.processlanguage prologue differs - hook skipped");
    else if (MH_CreateHook(p, (void *)hk_proclang, (void **)&o_proclang) == MH_OK && MH_EnableHook(p) == MH_OK) hooks++;
    else logf_("hook processlanguage failed");

    if (do_patches) {
        patches += patch_imm(base, RVA_MENU_CMP, CTX_MENU_CMP, sizeof CTX_MENU_CMP, 2, "settings menu: forward limit (cmp edi,7)");
        patches += patch_imm(base, RVA_MENU_WRAP, CTX_MENU_WRAP, sizeof CTX_MENU_WRAP, 3, "settings menu: backward wrap (LanguageChoice=7)");
    }
    InterlockedExchange(&g_hooks_ok, hooks);
    InterlockedExchange(&g_patches_ok, patches);
    logf_("installed: hooks %ld/2, menu patches %ld/2", hooks, patches);
}

/* ------------------------------------------------------------------ il2cpp resolve */
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
    RESOLVE(il2cpp_field_get_offset)
    RESOLVE(il2cpp_object_get_class)
    RESOLVE(il2cpp_string_new_utf16)
    RESOLVE(il2cpp_string_chars)
    RESOLVE(il2cpp_string_length)
    RESOLVE(il2cpp_gc_wbarrier_set_field)
    RESOLVE(il2cpp_gchandle_new)
    RESOLVE(il2cpp_gchandle_get_target)
    RESOLVE(il2cpp_thread_attach)
#undef RESOLVE
    return 1;
}

/* ------------------------------------------------------------------ self test (TRAINER_SELFTEST=1 or vi_selftest.flag) */
static int utf16_eq(Il2CppString *s, const wchar_t *w, uint32_t n) {
    return s && (uint32_t)il2cpp_string_length(s) == n && memcmp(il2cpp_string_chars(s), w, (size_t)n * 2) == 0;
}

static DWORD WINAPI selftest_thread(LPVOID unused) {
    (void)unused;
    char rep[MAX_PATH]; snprintf(rep, sizeof rep, "%s\\vi_selftest_report.json", g_dir);
    /* wait for a live UItexty (the game's persistent scene creates it right after the title) */
    for (int i = 0; i < 360 && !g_uit_any; i++) Sleep(500);
    Sleep(1500);
    il2cpp_thread_attach(il2cpp_domain_get());

    const char *dlg_status = "FAIL", *ui_status = "FAIL", *menu_status = "FAIL", *tab_status = "FAIL";
    int dlg_checked = 0, dlg_ok = 0, ui_checked = 0, ui_ok = 0, ui_extra = 0, dlg_unknown_ok = 0, dlg_space_codes = 0, dlg_multiline = 0;

    /* --- tables --- */
    if (g_dlg.count > 5000 && g_ui.count > 500) tab_status = "PASS";

    /* --- menu patches --- */
    {
        unsigned char *base = (unsigned char *)GetModuleHandleW(L"GameAssembly.dll");
        if (base && base[RVA_MENU_CMP + 2] == 0x08 && base[RVA_MENU_WRAP + 3] == 0x08 && base[RVA_MENU_CMP] == 0x83 && base[RVA_MENU_WRAP] == 0xC7) menu_status = "PASS";
    }

    /* --- dialogue: drive the real hook with a fake LocalizationData whose language == Portuguese slot --- */
    if (g_getvalue_target && g_dlg.count) {
        unsigned char fake[64]; memset(fake, 0, sizeof fake);
        *(int32_t *)(fake + OFF_LOCDATA_LANG) = VI_SLOT_LANGUAGE;
        Il2CppString *def = il2cpp_string_new_utf16((const uint16_t *)L"__DEFAULT__", 11);
        uint32_t step = g_dlg.count / 400; if (step == 0) step = 1;
        for (uint32_t i = 0; i < g_dlg.count; i += step) {
            Entry *e = &g_dlg.items[i];
            Il2CppString *code = il2cpp_string_new_utf16((const uint16_t *)e->key, (int32_t)e->klen);
            Il2CppString *got = g_getvalue_target(fake, code, def, NULL, NULL);
            dlg_checked++;
            /* duplicates: first occurrence wins, so compare against the table lookup, not against item i */
            Entry *first = table_find(&g_dlg, (const uint16_t *)e->key, e->klen);
            if (first && utf16_eq(got, first->val, first->vlen)) dlg_ok++;
            if (e->key[0] == L' ' || e->key[e->klen - 1] == L' ') dlg_space_codes++;
            for (uint32_t k = 0; k < e->vlen; k++) if (e->val[k] == L'\n') { dlg_multiline++; break; }
        }
        Il2CppString *bad = il2cpp_string_new_utf16((const uint16_t *)L"zz_code_that_does_not_exist_9f3", 31);
        Il2CppString *r = g_getvalue_target(fake, bad, def, NULL, NULL);
        dlg_unknown_ok = (r == def);
        /* a non-CONTENT column must be passed through to the game's own implementation, so we do not test it here */
        if (dlg_checked > 0 && dlg_ok == dlg_checked && dlg_unknown_ok) dlg_status = "PASS";
    }

    /* --- UI: apply to the live UItexty, read every field back, then restore the game's current language --- */
    void *uit = g_uit_any;
    if (uit && g_ui.count) {
        int miss = 0;
        int set = apply_ui(uit, &miss);
        for (uint32_t i = 0; i < g_ui.count; i++) {
            Entry *e = &g_ui.items[i];
            if (e->foff < 0) continue;
            ui_checked++;
            Il2CppString *cur = *(Il2CppString **)((char *)uit + e->foff);
            if (utf16_eq(cur, e->val, e->vlen)) ui_ok++;
        }
        ui_extra = miss;
        LONG lang = g_last_lang;
        if (o_proclang && lang >= -1 && lang != VI_SLOT_CHOICE) o_proclang(uit, lang, g_proclang_mi);   /* restore */
        else if (o_proclang && lang == VI_SLOT_CHOICE) { /* user is already on Vietnamese: leave as is */ }
        if (set > 500 && ui_ok == ui_checked && ui_checked == set) ui_status = "PASS";
    }

    const char *overall = (!strcmp(tab_status, "PASS") && !strcmp(dlg_status, "PASS") && !strcmp(ui_status, "PASS") && !strcmp(menu_status, "PASS") && g_hooks_ok == 2 && g_patches_ok == 2)
                          ? "PASS_READY_FOR_HUMAN" : "PARTIAL_FAIL_NEEDS_ISOLATED_HEAL";
    FILE *f = fopen(rep, "w");
    if (f) {
        fprintf(f,
            "{\n  \"overall_status\": \"%s\",\n  \"hooks_installed\": %ld,\n  \"menu_patches_applied\": %ld,\n"
            "  \"feature_results\": [\n"
            "    { \"subagent_branch_id\": \"SUBAGENT-TABLES-00\", \"status\": \"%s\", \"dialogue_entries\": %u, \"ui_entries\": %u },\n"
            "    { \"subagent_branch_id\": \"SUBAGENT-DIALOGUE-01\", \"status\": \"%s\", \"codes_checked\": %d, \"codes_correct\": %d, \"unknown_code_returns_default\": %d, \"codes_with_edge_spaces\": %d, \"multiline_values\": %d },\n"
            "    { \"subagent_branch_id\": \"SUBAGENT-UI-02\", \"status\": \"%s\", \"captured_ptr_valid\": %d, \"fields_checked\": %d, \"fields_correct\": %d, \"fields_missing_in_game\": %d, \"processlanguage_calls\": %ld },\n"
            "    { \"subagent_branch_id\": \"SUBAGENT-MENU-03\", \"status\": \"%s\", \"patches_applied\": %ld }\n"
            "  ]\n}\n",
            overall, g_hooks_ok, g_patches_ok,
            tab_status, g_dlg.count, g_ui.count,
            dlg_status, dlg_checked, dlg_ok, dlg_unknown_ok, dlg_space_codes, dlg_multiline,
            ui_status, uit != NULL, ui_checked, ui_ok, ui_extra, g_proclang_calls,
            menu_status, g_patches_ok);
        fclose(f);
    }
    logf_("self-test finished: %s", overall);
    return 0;
}

/* ------------------------------------------------------------------ init */
static DWORD WINAPI init_thread(LPVOID unused) {
    (void)unused;
    char env[8];
    if (GetEnvironmentVariableA("GSVI_DISABLE", env, sizeof env) && env[0] == '1') return 0;
    logf_("--- Ghost Song Vietnamese pack start. dir=%s", g_dir);
    char p1[MAX_PATH], p2[MAX_PATH];
    snprintf(p1, sizeof p1, "%s\\vi_dlg.tsv", g_datadir);
    snprintf(p2, sizeof p2, "%s\\vi_ui.tsv", g_datadir);
    int okd = table_load(&g_dlg, p1), oku = table_load(&g_ui, p2);
    if (!okd && !oku) { logf_("no translation tables - pack disabled"); return 0; }

    int ok = 0;
    for (int i = 0; i < 480; i++) {
        if (GetModuleHandleW(L"GameAssembly.dll") && resolve_api() && il2cpp_domain_get()) { ok = 1; break; }
        Sleep(250);
    }
    if (!ok) { logf_("il2cpp runtime never came up - pack disabled"); return 0; }
    /* il2cpp_init publishes the domain early; wait until the game's own classes can be resolved, i.e. the runtime is fully up */
    ok = 0;
    for (int i = 0; i < 480 && !ok; i++) {
        size_t n = 0;
        const Il2CppAssembly **asms = il2cpp_domain_get_assemblies(il2cpp_domain_get(), &n);
        for (size_t k = 0; asms && k < n && !ok; k++) {
            Il2CppImage *img = il2cpp_assembly_get_image(asms[k]);
            if (img && il2cpp_class_from_name(img, "", "UItexty")) ok = 1;
        }
        if (!ok) Sleep(250);
    }
    if (!ok) { logf_("game classes never appeared - pack disabled"); return 0; }
    logf_("il2cpp runtime ready");
    Sleep(1500);
    char stage[8] = "2";
    GetEnvironmentVariableA("GSVI_STAGE", stage, sizeof stage);
    if (stage[0] >= '1') install_all(stage[0] >= '2');
    else logf_("stage 0: nothing installed");

    char flag[MAX_PATH]; snprintf(flag, sizeof flag, "%s\\vi_selftest.flag", g_dir);
    int st = (GetEnvironmentVariableA("TRAINER_SELFTEST", env, sizeof env) && env[0] == '1') || GetFileAttributesA(flag) != INVALID_FILE_ATTRIBUTES;
    if (st) CreateThread(NULL, 0, selftest_thread, NULL, 0, NULL);
    return 0;
}

/* ------------------------------------------------------------------ winmm proxy glue */
#include "winmm_proxy.inc"

static void load_real_winmm(void) {
    wchar_t path[MAX_PATH];
    GetSystemDirectoryW(path, MAX_PATH);
    wcscat(path, L"\\winmm.dll");
    HMODULE real = LoadLibraryW(path);
    if (!real) return;
    for (int i = 0; i < GSVI_PROXY_COUNT; i++) {
        const char *nm = gsvi_proxy_names[i];
        gsvi_proxy_tab[i] = (void *)GetProcAddress(real, nm ? nm : (LPCSTR)(ULONG_PTR)gsvi_proxy_ords[i]);
    }
}

BOOL WINAPI DllMain(HINSTANCE h, DWORD reason, LPVOID r) {
    (void)r;
    if (reason == DLL_PROCESS_ATTACH) {
        DisableThreadLibraryCalls(h);
        load_real_winmm();
        GetModuleFileNameA(h, g_dir, MAX_PATH);
        char *s = strrchr(g_dir, '\\'); if (s) *s = 0;
        snprintf(g_datadir, sizeof g_datadir, "%s\\GhostSongVietnamese", g_dir);
        snprintf(g_logpath, sizeof g_logpath, "%s\\gs_vi.log", g_dir);
        /* only the game process (GhostSong.exe) runs the pack; tools that happen to load this DLL stay inert */
        char exe[MAX_PATH]; GetModuleFileNameA(NULL, exe, MAX_PATH);
        const char *b = strrchr(exe, '\\'); b = b ? b + 1 : exe;
        if (_stricmp(b, "GhostSong.exe") == 0) CreateThread(NULL, 0, init_thread, NULL, 0, NULL);
    }
    return TRUE;
}
