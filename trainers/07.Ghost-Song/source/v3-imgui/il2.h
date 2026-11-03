/*
 * Minimal il2cpp C-API binding.  GameAssembly.dll exports the whole public il2cpp API,
 * so every class / field / method is looked up BY NAME at run time (no hard-coded RVAs).
 */
#ifndef GS3_IL2_H
#define GS3_IL2_H

#include <stddef.h>
#include <stdint.h>

typedef struct Il2CppDomain   Il2CppDomain;
typedef struct Il2CppAssembly Il2CppAssembly;
typedef struct Il2CppImage    Il2CppImage;
typedef struct Il2CppClass    Il2CppClass;
typedef struct Il2CppField    Il2CppField;
typedef struct Il2CppMethod   Il2CppMethod;   /* MethodInfo; first member = methodPointer */
typedef struct Il2CppObject   Il2CppObject;
typedef struct Il2CppType     Il2CppType;
typedef struct Il2CppThread   Il2CppThread;

#define IL2_API(ret, name, args) extern ret (*name) args;
IL2_API(Il2CppDomain *,          il2cpp_domain_get, (void))
IL2_API(const Il2CppAssembly **, il2cpp_domain_get_assemblies, (const Il2CppDomain *, size_t *))
IL2_API(Il2CppImage *,           il2cpp_assembly_get_image, (const Il2CppAssembly *))
IL2_API(Il2CppClass *,           il2cpp_class_from_name, (Il2CppImage *, const char *, const char *))
IL2_API(Il2CppField *,           il2cpp_class_get_field_from_name, (Il2CppClass *, const char *))
IL2_API(Il2CppMethod *,          il2cpp_class_get_method_from_name, (Il2CppClass *, const char *, int))
IL2_API(Il2CppMethod *,          il2cpp_class_get_methods, (Il2CppClass *, void **))
IL2_API(const char *,            il2cpp_method_get_name, (const Il2CppMethod *))
IL2_API(uint32_t,                il2cpp_method_get_param_count, (const Il2CppMethod *))
IL2_API(const Il2CppType *,      il2cpp_method_get_param, (const Il2CppMethod *, uint32_t))
IL2_API(int,                     il2cpp_type_get_type, (const Il2CppType *))
IL2_API(size_t,                  il2cpp_field_get_offset, (Il2CppField *))
IL2_API(void,                    il2cpp_field_static_get_value, (Il2CppField *, void *))
IL2_API(Il2CppObject *,          il2cpp_runtime_invoke, (const Il2CppMethod *, void *, void **, Il2CppObject **))
IL2_API(Il2CppObject *,          il2cpp_string_new, (const char *))
IL2_API(Il2CppThread *,          il2cpp_thread_attach, (Il2CppDomain *))
IL2_API(const char *,            il2cpp_image_get_name, (const Il2CppImage *))
IL2_API(const char *,            il2cpp_class_get_name, (Il2CppClass *))
#undef IL2_API

/* ELEMENT_TYPE values returned by il2cpp_type_get_type */
#define IL2T_BOOLEAN 0x02
#define IL2T_I4      0x08
#define IL2T_R4      0x0C

/* Il2CppClass::static_fields (metadata v27 / Unity 2020.3, x64) - validated at start-up */
#define IL2_CLASS_STATIC_FIELDS_OFF 0xB8

/* managed array: 0x18 = length, 0x20.. = elements */
#define IL2_ARR_LEN(a)  (*(uint32_t *)((char *)(a) + 0x18))
#define IL2_ARR_ELEM(a, i) (*(void **)((char *)(a) + 0x20 + 8 * (size_t)(i)))

int  il2_bind(void);                                   /* resolve API from GameAssembly.dll; 0 = ok */
Il2CppClass *il2_find_class(const char *ns, const char *name);
Il2CppClass *il2_find_class_in(const char *image_prefix, const char *ns, const char *name);
Il2CppMethod *il2_find_method(Il2CppClass *k, const char *name, int argc);
void *il2_method_ptr(const Il2CppMethod *m);           /* MethodInfo->methodPointer */
char *il2_static_base(Il2CppClass *k);                 /* class static block or NULL until the class is initialised */

#endif
