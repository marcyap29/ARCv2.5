#include <stddef.h>

// Weak stub implementations for missing backend registration functions
// These will only be used if the actual functions are not available

extern "C" {

// Forward declarations for GGML types
struct ggml_backend_reg;
struct ggml_backend_device;
typedef struct ggml_backend_reg * ggml_backend_reg_t;
typedef struct ggml_backend_device * ggml_backend_dev_t;

// Backend registration stubs (weak symbols)
__attribute__((weak))
size_t ggml_backend_reg_count(void) {
    return 0;
}

__attribute__((weak))
ggml_backend_reg_t ggml_backend_reg_by_name(const char* name) {
    (void)name; // Suppress unused parameter warning
    return nullptr;
}

__attribute__((weak))
int ggml_backend_init_by_type(int type, const char* params) {
    (void)type;
    (void)params;
    return 0;
}

__attribute__((weak))
size_t ggml_backend_dev_count(void) {
    return 0;
}

__attribute__((weak))
ggml_backend_dev_t ggml_backend_dev_get(size_t index) {
    (void)index;
    return nullptr;
}

__attribute__((weak))
ggml_backend_dev_t ggml_backend_dev_by_type(int type) {
    (void)type;
    return nullptr;
}

} // extern "C"
