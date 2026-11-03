/*
 * Minimal IL2CPP runtime API bindings for the Ghost Song Vietnamese language pack.
 * GameAssembly.dll (Unity 2020.3.36f1, metadata v27) exports the whole standard il2cpp C API.
 */
#ifndef GSVI_IL2CPP_H
#define GSVI_IL2CPP_H

#include <stddef.h>
#include <stdint.h>

typedef struct Il2CppDomain Il2CppDomain;
typedef struct Il2CppAssembly Il2CppAssembly;
typedef struct Il2CppImage Il2CppImage;
typedef struct Il2CppClass Il2CppClass;
typedef struct Il2CppFieldInfo Il2CppFieldInfo;
typedef struct Il2CppMethodInfo Il2CppMethodInfo;
typedef struct Il2CppObject Il2CppObject;
typedef struct Il2CppString Il2CppString;

extern Il2CppDomain *(*il2cpp_domain_get)(void);
extern const Il2CppAssembly **(*il2cpp_domain_get_assemblies)(Il2CppDomain *domain, size_t *size);
extern Il2CppImage *(*il2cpp_assembly_get_image)(const Il2CppAssembly *assembly);
extern Il2CppClass *(*il2cpp_class_from_name)(Il2CppImage *image, const char *namespaze, const char *name);
extern Il2CppFieldInfo *(*il2cpp_class_get_field_from_name)(Il2CppClass *klass, const char *name);
extern size_t (*il2cpp_field_get_offset)(Il2CppFieldInfo *field);
extern Il2CppClass *(*il2cpp_object_get_class)(Il2CppObject *obj);
extern Il2CppString *(*il2cpp_string_new_utf16)(const uint16_t *text, int32_t len);
extern uint16_t *(*il2cpp_string_chars)(Il2CppString *str);
extern int32_t (*il2cpp_string_length)(Il2CppString *str);
extern void (*il2cpp_gc_wbarrier_set_field)(Il2CppObject *obj, void **target, void *value);
extern uint32_t (*il2cpp_gchandle_new)(Il2CppObject *obj, int32_t pinned);
extern Il2CppObject *(*il2cpp_gchandle_get_target)(uint32_t handle);
extern void *(*il2cpp_thread_attach)(Il2CppDomain *domain);

#endif /* GSVI_IL2CPP_H */
