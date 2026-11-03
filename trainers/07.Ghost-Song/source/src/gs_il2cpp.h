/*
 * Minimal IL2CPP runtime API bindings for the Ghost Song trainer.
 *
 * GameAssembly.dll (Unity 2020.3.36f1, metadata v27) exports the complete
 * standard il2cpp C API, so the trainer can look everything up BY NAME
 * instead of hardcoding struct offsets.  Only the handful of entry points
 * the trainer actually needs are declared here.
 */
#ifndef GS_IL2CPP_H
#define GS_IL2CPP_H

#include <stddef.h>
#include <stdint.h>

typedef struct Il2CppDomain Il2CppDomain;
typedef struct Il2CppAssembly Il2CppAssembly;
typedef struct Il2CppImage Il2CppImage;
typedef struct Il2CppClass Il2CppClass;
typedef struct Il2CppFieldInfo Il2CppFieldInfo;
typedef struct Il2CppMethodInfo Il2CppMethodInfo;
typedef struct Il2CppObject Il2CppObject;
typedef struct Il2CppArray Il2CppArray;
typedef struct Il2CppType Il2CppType;

/* --- resolved at runtime from GameAssembly.dll --- */
extern Il2CppDomain *(*il2cpp_domain_get)(void);
extern const Il2CppAssembly **(*il2cpp_domain_get_assemblies)(Il2CppDomain *domain, size_t *size);
extern Il2CppImage *(*il2cpp_assembly_get_image)(const Il2CppAssembly *assembly);
extern Il2CppClass *(*il2cpp_class_from_name)(Il2CppImage *image, const char *namespaze, const char *name);
extern Il2CppFieldInfo *(*il2cpp_class_get_field_from_name)(Il2CppClass *klass, const char *name);
extern Il2CppMethodInfo *(*il2cpp_class_get_method_from_name)(Il2CppClass *klass, const char *name, int argc);
extern size_t (*il2cpp_field_get_offset)(Il2CppFieldInfo *field);
extern void (*il2cpp_field_static_get_value)(Il2CppFieldInfo *field, void *value);
extern void (*il2cpp_field_static_set_value)(Il2CppFieldInfo *field, void *value);
extern void (*il2cpp_field_get_value)(Il2CppObject *obj, Il2CppFieldInfo *field, void *value);
extern Il2CppObject *(*il2cpp_runtime_invoke)(Il2CppMethodInfo *method, void *obj, void **params, Il2CppObject **exc);
extern uint32_t (*il2cpp_array_length)(Il2CppArray *array);
extern const char *(*il2cpp_class_get_name)(Il2CppClass *klass);

#endif /* GS_IL2CPP_H */
