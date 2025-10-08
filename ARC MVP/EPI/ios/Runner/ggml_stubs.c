// Minimal stubs for missing GGML backend functions
// This file provides the missing functions without conflicting with headers

#include <stddef.h>

// Simple stubs that return safe defaults
size_t ggml_backend_reg_count(void) {
    return 0;
}

void* ggml_backend_reg_by_name(const char* name) {
    (void)name; // Suppress unused parameter warning
    return NULL;
}

int ggml_backend_init_by_type(int type, const char* params) {
    (void)type;
    (void)params;
    return 0;
}

size_t ggml_backend_dev_count(void) {
    return 0;
}

void* ggml_backend_dev_get(size_t index) {
    (void)index;
    return NULL;
}

void* ggml_backend_dev_by_type(int type) {
    (void)type;
    return NULL;
}
