/*
 * Storage for the il2cpp entry points the trainer resolves at runtime from
 * GameAssembly.dll.  Keeping them in their own translation unit means the
 * linker never tries to resolve them against a static import library.
 */
#include "gs_il2cpp.h"

Il2CppDomain *(*il2cpp_domain_get)(void) = NULL;
const Il2CppAssembly **(*il2cpp_domain_get_assemblies)(Il2CppDomain *domain, size_t *size) = NULL;
Il2CppImage *(*il2cpp_assembly_get_image)(const Il2CppAssembly *assembly) = NULL;
Il2CppClass *(*il2cpp_class_from_name)(Il2CppImage *image, const char *namespaze, const char *name) = NULL;
Il2CppFieldInfo *(*il2cpp_class_get_field_from_name)(Il2CppClass *klass, const char *name) = NULL;
Il2CppMethodInfo *(*il2cpp_class_get_method_from_name)(Il2CppClass *klass, const char *name, int argc) = NULL;
size_t (*il2cpp_field_get_offset)(Il2CppFieldInfo *field) = NULL;
void (*il2cpp_field_static_get_value)(Il2CppFieldInfo *field, void *value) = NULL;
void (*il2cpp_field_static_set_value)(Il2CppFieldInfo *field, void *value) = NULL;
void (*il2cpp_field_get_value)(Il2CppObject *obj, Il2CppFieldInfo *field, void *value) = NULL;
Il2CppObject *(*il2cpp_runtime_invoke)(Il2CppMethodInfo *method, void *obj, void **params, Il2CppObject **exc) = NULL;
uint32_t (*il2cpp_array_length)(Il2CppArray *array) = NULL;
const char *(*il2cpp_class_get_name)(Il2CppClass *klass) = NULL;
