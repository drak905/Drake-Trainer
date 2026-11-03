#include <windows.h>
#include <string.h>
#include "il2.h"

#define DEF(ret, name, args) ret (*name) args = NULL;
DEF(Il2CppDomain *,          il2cpp_domain_get, (void))
DEF(const Il2CppAssembly **, il2cpp_domain_get_assemblies, (const Il2CppDomain *, size_t *))
DEF(Il2CppImage *,           il2cpp_assembly_get_image, (const Il2CppAssembly *))
DEF(Il2CppClass *,           il2cpp_class_from_name, (Il2CppImage *, const char *, const char *))
DEF(Il2CppField *,           il2cpp_class_get_field_from_name, (Il2CppClass *, const char *))
DEF(Il2CppMethod *,          il2cpp_class_get_method_from_name, (Il2CppClass *, const char *, int))
DEF(Il2CppMethod *,          il2cpp_class_get_methods, (Il2CppClass *, void **))
DEF(const char *,            il2cpp_method_get_name, (const Il2CppMethod *))
DEF(uint32_t,                il2cpp_method_get_param_count, (const Il2CppMethod *))
DEF(const Il2CppType *,      il2cpp_method_get_param, (const Il2CppMethod *, uint32_t))
DEF(int,                     il2cpp_type_get_type, (const Il2CppType *))
DEF(size_t,                  il2cpp_field_get_offset, (Il2CppField *))
DEF(void,                    il2cpp_field_static_get_value, (Il2CppField *, void *))
DEF(Il2CppObject *,          il2cpp_runtime_invoke, (const Il2CppMethod *, void *, void **, Il2CppObject **))
DEF(Il2CppObject *,          il2cpp_string_new, (const char *))
DEF(Il2CppThread *,          il2cpp_thread_attach, (Il2CppDomain *))
DEF(const char *,            il2cpp_image_get_name, (const Il2CppImage *))
DEF(const char *,            il2cpp_class_get_name, (Il2CppClass *))
#undef DEF

int il2_bind(void)
{
    HMODULE ga = GetModuleHandleA("GameAssembly.dll");
    if (!ga) return 1;
#define BIND(n) do { *(FARPROC *)&n = GetProcAddress(ga, #n); if (!n) return 2; } while (0)
    BIND(il2cpp_domain_get);
    BIND(il2cpp_domain_get_assemblies);
    BIND(il2cpp_assembly_get_image);
    BIND(il2cpp_class_from_name);
    BIND(il2cpp_class_get_field_from_name);
    BIND(il2cpp_class_get_method_from_name);
    BIND(il2cpp_class_get_methods);
    BIND(il2cpp_method_get_name);
    BIND(il2cpp_method_get_param_count);
    BIND(il2cpp_method_get_param);
    BIND(il2cpp_type_get_type);
    BIND(il2cpp_field_get_offset);
    BIND(il2cpp_field_static_get_value);
    BIND(il2cpp_runtime_invoke);
    BIND(il2cpp_string_new);
    BIND(il2cpp_thread_attach);
    BIND(il2cpp_image_get_name);
    BIND(il2cpp_class_get_name);
#undef BIND
    return 0;
}

Il2CppClass *il2_find_class_in(const char *image_prefix, const char *ns, const char *name)
{
    Il2CppDomain *dom = il2cpp_domain_get();
    if (!dom) return NULL;
    size_t n = 0;
    const Il2CppAssembly **as = il2cpp_domain_get_assemblies(dom, &n);
    if (!as) return NULL;
    for (size_t i = 0; i < n; i++) {
        Il2CppImage *img = il2cpp_assembly_get_image(as[i]);
        if (!img) continue;
        if (image_prefix) {
            const char *in = il2cpp_image_get_name(img);
            if (!in || _strnicmp(in, image_prefix, strlen(image_prefix)) != 0) continue;
        }
        Il2CppClass *k = il2cpp_class_from_name(img, ns, name);
        if (k) return k;
    }
    return NULL;
}

Il2CppClass *il2_find_class(const char *ns, const char *name) { return il2_find_class_in(NULL, ns, name); }

Il2CppMethod *il2_find_method(Il2CppClass *k, const char *name, int argc)
{
    return k ? il2cpp_class_get_method_from_name(k, name, argc) : NULL;
}

void *il2_method_ptr(const Il2CppMethod *m)
{
    return m ? *(void *const *)m : NULL;
}

char *il2_static_base(Il2CppClass *k)
{
    if (!k) return NULL;
    return *(char **)((char *)k + IL2_CLASS_STATIC_FIELDS_OFF);
}
