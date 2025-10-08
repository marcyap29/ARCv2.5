#pragma once
#ifdef __cplusplus
extern "C" {
#endif

typedef void (*epi_logger_t)(int level, const char* msg);

// Register a host-provided logger (Swift/ObjC). Optional.
void epi_set_logger(epi_logger_t cb);

// Simple printf-style logger that calls the callback if set,
// otherwise writes to stderr.
void epi_logf(int level, const char* fmt, ...);

#ifdef __cplusplus
}
#endif
