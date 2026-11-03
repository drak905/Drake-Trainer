#include "gsvi_il2cpp.h"

Il2CppDomain *(*il2cpp_domain_get)(void) = NULL;
const Il2CppAssembly **(*il2cpp_domain_get_assemblies)(Il2CppDomain *domain, size_t *size) = NULL;
Il2CppImage *(*il2cpp_assembly_get_image)(const Il2CppAssembly *assembly) = NULL;
Il2CppClass *(*il2cpp_class_from_name)(Il2CppImage *image, const char *namespaze, const char *name) = NULL;
Il2CppFieldInfo *(*il2cpp_class_get_field_from_name)(Il2CppClass *klass, const char *name) = NULL;
size_t (*il2cpp_field_get_offset)(Il2CppFieldInfo *field) = NULL;
Il2CppClass *(*il2cpp_object_get_class)(Il2CppObject *obj) = NULL;
Il2CppString *(*il2cpp_string_new_utf16)(const uint16_t *text, int32_t len) = NULL;
uint16_t *(*il2cpp_string_chars)(Il2CppString *str) = NULL;
int32_t (*il2cpp_string_length)(Il2CppString *str) = NULL;
void (*il2cpp_gc_wbarrier_set_field)(Il2CppObject *obj, void **target, void *value) = NULL;
uint32_t (*il2cpp_gchandle_new)(Il2CppObject *obj, int32_t pinned) = NULL;
Il2CppObject *(*il2cpp_gchandle_get_target)(uint32_t handle) = NULL;
void *(*il2cpp_thread_attach)(Il2CppDomain *domain) = NULL;
