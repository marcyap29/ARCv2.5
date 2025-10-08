#include "epi_logger.h"
#include <atomic>
#include <cstdarg>
#include <cstdio>

static std::atomic<epi_logger_t> s_cb{nullptr};

extern "C" void epi_set_logger(epi_logger_t cb) { 
    s_cb.store(cb, std::memory_order_release); 
}

extern "C" void epi_logf(int level, const char* fmt, ...) {
    char buf[2048];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    if (auto cb = s_cb.load(std::memory_order_acquire)) {
        cb(level, buf);
    } else {
        // fall back to stderr so you get *something* even before Swift installs the logger
        fprintf(stderr, "[EPI %d] %s\n", level, buf);
        fflush(stderr);
    }
}
