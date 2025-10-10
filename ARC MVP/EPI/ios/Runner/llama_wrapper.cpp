#include "llama_wrapper.h"
#include "epi_logger.h"
#include "../../third_party/llama.cpp/include/llama.h"
#include "llama_compat_simple.hpp"
#include <vector>
#include <string>
#include <cstring>
#include <algorithm>
#include <cassert>
#include <atomic>
#include <mutex>
#include <thread>
#include <signal.h>
#include <memory>
#include <cmath>
#include <cstdlib>

// Request Gate implementation (inline to avoid separate compilation)
class RequestGate {
public:
  static bool begin(uint64_t id) {
    uint64_t expected = 0;
    const bool ok = s_inFlight.compare_exchange_strong(expected, id);
    epi_logf(3, ok ? "RequestGate::begin ok %llu"
                   : "RequestGate::begin busy cur=%llu req=%llu",
             ok ? id : expected, id);
    return ok;
  }
  static void end(uint64_t id) {
    const uint64_t cur = s_inFlight.load();
    if (cur == id) {
      s_inFlight.store(0);
      epi_logf(3, "RequestGate::end released %llu", id);
    } else {
      epi_logf(1, "RequestGate::end mismatch cur=%llu req=%llu", cur, id);
    }
  }
  static uint64_t current() { return s_inFlight.load(); }
  static bool isBusy() { return s_inFlight.load() != 0; }
private:
  static std::atomic<uint64_t> s_inFlight;
};

std::atomic<uint64_t> RequestGate::s_inFlight{0};

// C wrappers for Swift
extern "C" bool RequestGate_begin(uint64_t request_id) {
    return RequestGate::begin(request_id);
}

extern "C" void RequestGate_end(uint64_t request_id) {
    RequestGate::end(request_id);
}

extern "C" uint64_t RequestGate_current(void) {
    return RequestGate::current();
}

// Modern handle-based approach
struct epi_handle_t {
    llama_model *   model  = nullptr;
    llama_context * ctx    = nullptr;
    llama_batch     batch  = {};
    int32_t         n_vocab = 0;
    bool            started = false;
    void*           sampler = nullptr;  // Will be llama_sampler_t when available
    
    // Modern API state - keep prompt and tokens alive across start/feed:
    std::string          prompt_copy;
    std::vector<llama_token> prompt_toks;
    epi_callbacks        cbs{nullptr, nullptr};
    bool                 modern_mode = false;
    
    // Generation state
    int32_t              n_predict = 256;
    int32_t              n_prompt_tokens = 0;
    int32_t              n_generated = 0;
    llama_token          next_token = 0;
    
    // Re-entrancy protection - instance-based, not static
    std::atomic<bool>    feeding{false};
    std::atomic<bool>    starting{false};
};

// Global state
static std::atomic<epi_handle_t*> g_handle{nullptr};
static std::atomic<int> g_state{0}; // 0=Uninit,1=Init,2=Running
static std::atomic<bool> g_generating{false}; // Prevent overlapping generation
static std::mutex g_mu;

// Thread ID helper
static inline unsigned long tid() {
#if defined(__APPLE__)
    uint64_t id;
    pthread_threadid_np(nullptr, &id);
    return (unsigned long)id;
#else
    return (unsigned long)std::hash<std::thread::id>{}(std::this_thread::get_id());
#endif
}

// Helper: get token id for a special string (e.g. "<|eot_id|>")
static llama_token token_id_for(const llama_model* model, const char* piece) {
    std::vector<llama_token> tmp(8);
    const llama_vocab* vocab = llama_model_get_vocab(model);
    const int n = llama_tokenize(vocab, piece, std::strlen(piece),
                                 tmp.data(), (int)tmp.size(),
                                 /*add_special*/ true, /*parse_special*/ true);
    return (n > 0) ? tmp[0] : (llama_token)-1;
}

// Signal handler for crash detection
static void epi_sig_handler(int sig) {
    epi_logf(3, "FATAL signal %d", sig);
    _Exit(128 + sig);
}

static void epi_install_signals() {
    signal(SIGSEGV, epi_sig_handler);
    signal(SIGBUS,  epi_sig_handler);
    signal(SIGABRT, epi_sig_handler);
}

// Helper function to feed prompt tokens in chunks
static int feed_prompt_chunks(llama_context* ctx, const std::vector<llama_token>& toks) {
    const int chunk = 256;
    int off = 0;
    static llama_seq_id seq_id = 0; // Single sequence ID
    
    while (off < (int)toks.size()) {
        const int n = std::min(chunk, (int)toks.size() - off);

        llama_batch batch = llama_batch_init(n, /*embd*/0, /*alloc*/1);
        if (!batch.token) {
            epi_logf(3, "feed: batch init failed (off=%d n=%d)", off, n);
            return -20;
        }
        
        for (int i = 0; i < n; ++i) {
            int pos = off + i;
            batch.token[batch.n_tokens] = toks[off + i];
            batch.pos[batch.n_tokens] = pos;
            batch.n_seq_id[batch.n_tokens] = 1;
            batch.seq_id[batch.n_tokens] = &seq_id;
            batch.logits[batch.n_tokens] = (i == n - 1) ? 1 : 0; // Only last token needs logits
            batch.n_tokens++;
        }

        int rc = llama_decode(ctx, batch);
        if (rc != 0) {
            epi_logf(3, "feed: decode failed rc=%d (off=%d n=%d)", rc, off, n);
            llama_batch_free(batch);
            return -30;
        }
        epi_logf(1, "feed: off=%d n=%d decode ok", off, n);
        llama_batch_free(batch);
        off += n;
    }
                return 0;
            }

// Bullet-proof start_core implementation
static int start_core(epi_handle_t* h, const char* prompt_utf8) noexcept {
    if (!h) return -2;
    if (!prompt_utf8 || !*prompt_utf8) return -3;

    // 1) Robust tokenization (two-pass)
    std::vector<llama_token> toks;
    {
        const llama_vocab* vocab = llama_model_get_vocab(h->model);
        if (!vocab) {
            epi_logf(3, "tokenize failed: no vocab");
            return -10;
        }
        
        bool add_bos = true;  // Phi models often expect BOS
        bool parse_special = true;
        size_t prompt_len = strlen(prompt_utf8);
        
        // First call with null to get needed size (returned as negative)
        int needed = llama_tokenize(vocab, prompt_utf8, prompt_len, nullptr, 0, add_bos ? 1 : 0, parse_special ? 1 : 0);
        if (needed == 0) {
            epi_logf(3, "tokenize failed: empty input");
            return -3;
        }
        if (needed > 0) {
            // Some builds may return positive "needed"; handle both
        } else {
            needed = -needed;  // negative means required count
        }
        
        epi_logf(1, "tokenize: need %d tokens for %zu bytes", needed, prompt_len);
        
        toks.resize(needed);
        int n = llama_tokenize(vocab, prompt_utf8, prompt_len, toks.data(), needed, add_bos ? 1 : 0, parse_special ? 1 : 0);
        if (n < 0) n = -n;  // should not happen now, but be safe
        if (n <= 0) {
            epi_logf(3, "tokenize failed: produced %d tokens", n);
            return -10;
        }
        toks.resize(n);
        
        epi_logf(1, "tokenize ok: n_tokens=%d head=[%d,%d,%d...]",
                 n, toks[0], toks.size()>1?toks[1]:-1, toks.size()>2?toks[2]:-1);
        
        const int n_ctx = llama_n_ctx(h->ctx);
        if (n >= n_ctx) {
            int headroom = std::max(32, std::min(128, n_ctx/8));
            toks.resize(std::max(1, n_ctx - headroom));
            epi_logf(2, "truncate: toks=%d ctx=%d headroom=%d", (int)toks.size(), n_ctx, headroom);
        }
    }

    // 2) Clear KV cache
    llama_memory_t mem = llama_get_memory(h->ctx);
    if (mem) {
        llama_memory_clear(mem, true);
        epi_logf(1, "kv cleared");
    }

    // 3) Ingest full prompt in chunks (no sampling yet)
    int rc = feed_prompt_chunks(h->ctx, toks);
    if (rc != 0) return rc;
    epi_logf(1, "prompt ingest complete");

    // 4) Sampler initialization (simplified for now - use greedy sampling)
    epi_logf(1, "using simple greedy sampling");

    // 5) Generate N tokens safely
    int produced = 0;
    int max_out = 32; // keep small for bring-up
    static llama_seq_id seq_id = 0; // Single sequence ID
    
    while (produced < max_out) {
        // Get logits for sampling
        const float* logits = llama_get_logits_ith(h->ctx, 0);
        if (!logits) {
            epi_logf(3, "no logits available for sampling at produced=%d", produced);
            return -50;
        }
        
        // Simple greedy sampling
        int32_t best_token = 0;
        float best_logit = logits[0];
        int32_t n_vocab = llama_vocab_n_tokens(llama_model_get_vocab(h->model));
        for (int32_t i = 1; i < n_vocab; ++i) {
            if (logits[i] > best_logit) {
                best_logit = logits[i];
                best_token = i;
            }
        }
        
        // Check for EOS
        int32_t eos_token = llama_vocab_eos(llama_model_get_vocab(h->model));
        if (best_token == eos_token) {
            epi_logf(1, "eos at %d", produced);
            break;
        }

        // Send token back to model (single-token batch)
        llama_batch batch = llama_batch_init(1, 0, 1);
        if (!batch.token) {
            epi_logf(3, "gen: batch init failed at produced=%d", produced);
            return -20;
        }
        
        int pos = (int)toks.size() + produced;
        batch.token[0] = best_token;
        batch.pos[0] = pos;
        batch.n_seq_id[0] = 1;
        batch.seq_id[0] = &seq_id;
        batch.logits[0] = true;
        batch.n_tokens = 1;

        rc = llama_decode(h->ctx, batch);
        if (rc != 0) {
            epi_logf(3, "gen: decode rc=%d at produced=%d", rc, produced);
            llama_batch_free(batch);
            return -31;
        }
        llama_batch_free(batch);

        produced++;
        // Optional: emit token to Swift via callback here
        // epi_emit_token(best_token);
        if ((produced % 4) == 0) epi_logf(1, "gen: produced=%d", produced);
    }

    epi_logf(1, "gen: DONE produced=%d", produced);
    h->started = true;
    g_state.store(2, std::memory_order_release);
    return 0;
}

extern "C" {


bool epi_llama_init(const char* model_path, int32_t n_ctx, int32_t n_gpu_layers) {
    std::lock_guard<std::mutex> lk(g_mu);
    epi_logf(1, "ENTER init tid=%lu state=%d handle=%p path=%s ctx=%d gpu=%d", 
             tid(), g_state.load(), g_handle.load(), model_path, n_ctx, n_gpu_layers);
    
    // Guard against double initialization
    static std::atomic<bool> s_inited{false};
    if (s_inited.exchange(true)) {
        epi_logf(1, "init: already initialized; skipping");
        return true;
    }
    
    // Install signal handlers for crash detection
    epi_install_signals();
    
    // Initialize backend
    llama_backend_init();
    
    // Load model
    llama_model_params mparams = llama_model_default_params();
    mparams.n_gpu_layers = n_gpu_layers;  // Set GPU layers in model params
    llama_model * model = llama_load_model_from_file(model_path, mparams);
    if (!model) {
        epi_logf(3, "llama_load_model_from_file failed");
        llama_backend_free();
        return false;
    }
    
    // Create context
    llama_context_params cparams = llama_context_default_params();
    cparams.n_ctx = n_ctx;
    // Note: n_gpu_layers is now set in model_params, not context_params
    
    llama_context * ctx = llama_new_context_with_model(model, cparams);
    if (!ctx) {
        epi_logf(3, "llama_new_context_with_model failed");
        llama_free_model(model);
        llama_backend_free();
        return false;
    }
    
    // Create handle
    auto * h = new epi_handle_t();
    h->model = model;
    h->ctx = ctx;
    h->batch = llama_batch_init(512, 0, 1);
    h->n_vocab = llama_vocab_n_tokens(llama_model_get_vocab(model));
    h->started = false;
    
    // No sampling context needed - using core API directly
    
    g_handle.store(h, std::memory_order_release);
    g_state.store(1, std::memory_order_release);
    
    // Runtime metal detection - more accurate than compile-time check
    const std::string sys = llama_print_system_info();
    const bool metalCompiled = sys.find("metal") != std::string::npos;
    const bool metalEngaged = sys.find("offloading") != std::string::npos && sys.find("GPU") != std::string::npos;
    
    if (metalEngaged) {
        // Extract layer count from system info if possible
        epi_logf(1, "metal: engaged (%d layers)", n_gpu_layers);
    } else if (metalCompiled) {
        epi_logf(1, "metal: compiled in (not engaged)");
    } else {
        epi_logf(1, "metal: not compiled");
    }
    epi_logf(1, "gpu layers requested=%d", n_gpu_layers);
    
    epi_logf(1, "EXIT  init tid=%lu state=%d handle=%p SUCCESS", 
             tid(), g_state.load(), g_handle.load());
    return true;
}

void epi_llama_free(void) {
    std::lock_guard<std::mutex> lk(g_mu);
    epi_logf(1, "ENTER free  tid=%lu state=%d handle=%p", 
             tid(), g_state.load(), g_handle.load());
    
    auto* h = g_handle.exchange(nullptr, std::memory_order_acq_rel);
    if (h) {
        epi_logf(1, "freeing handle components");
        // Free batch if it has tokens
        if (h->batch.n_tokens > 0) {
            llama_batch_free(h->batch);
        }
        if (h->ctx) {
            llama_free(h->ctx);
        }
        if (h->model) {
            llama_free_model(h->model);
        }
        delete h;
        epi_logf(1, "handle freed successfully");
            } else {
        epi_logf(1, "no handle to free");
    }
    
    g_state.store(0, std::memory_order_release);
    llama_backend_free();
    epi_logf(1, "EXIT  free  tid=%lu state=%d handle=%p", 
             tid(), g_state.load(), g_handle.load());
}

bool epi_llama_start(const char* prompt_utf8) {
    std::lock_guard<std::mutex> lk(g_mu);
    epi_logf(1, "ENTER start tid=%lu state=%d handle=%p", 
             tid(), g_state.load(), g_handle.load());
    
    // Check if already generating
    bool expected = false;
    if (!g_generating.compare_exchange_strong(expected, true)) {
        epi_logf(3, "generation already in progress - ignoring duplicate call");
        return false;
    }
    
    int code = -99;
    try {
        code = start_core(g_handle.load(std::memory_order_acquire), prompt_utf8);
    } catch (...) {
        epi_logf(3, "unhandled C++ exception in start_core");
        code = -98;
    }
    
    // Always reset generation flag
    g_generating = false;
    
    bool success = (code == 0);
    epi_logf(1, "EXIT  start code=%d success=%s", code, success ? "true" : "false");
    return success;
}

bool epi_llama_start_with_fallback(const char* prompt_utf8) {
    // Try with current settings first
    if (epi_llama_start(prompt_utf8)) {
        return true;
    }
    
    epi_logf(2, "retrying with CPU fallback (n_gpu_layers=0)");
    
    // For now, just return false since CPU fallback is not implemented
    // The issue is that we need the model path to reinitialize, but we don't store it
    epi_logf(3, "CPU fallback not implemented - need model path");
    return false;
}

// Modern streaming API implementation
bool epi_start(const char* prompt_utf8, const epi_gen_params* p, epi_callbacks cbs, uint64_t request_id) {
    std::lock_guard<std::mutex> lk(g_mu);
    epi_logf(1, "ENTER epi_start tid=%lu state=%d handle=%p request_id=%llu", 
             tid(), g_state.load(), g_handle.load(), request_id);
    
    auto* h = g_handle.load(std::memory_order_acquire);
    if (!h) {
        epi_logf(3, "epi_start aborted: handle is null");
        return false;
    }
    
    if (!prompt_utf8 || *prompt_utf8 == 0) {
        epi_logf(3, "epi_start aborted: empty prompt");
        return false;
    }
    
    // Global request gate - prevent duplicate calls
    if (!RequestGate::begin(request_id)) {
        epi_logf(3, "epi_start rejected: request %llu already in flight (current: %llu)", 
                 request_id, RequestGate::current());
        return false;
    }
    
    // Scope guard for guaranteed cleanup
    auto cleanup_guard = [&]() {
        RequestGate::end(request_id);
        h->starting = false;
        g_generating = false;
    };
    
    // Instance-based re-entrancy guard for epi_start
    bool expected = false;
    if (!h->starting.compare_exchange_strong(expected, true)) {
        epi_logf(3, "epi_start already in progress - ignoring duplicate call (request_id=%llu)", request_id);
        cleanup_guard();
        return false;
    }
    
    // Check if already generating
    expected = false;
    if (!g_generating.compare_exchange_strong(expected, true)) {
        epi_logf(3, "generation already in progress - ignoring duplicate call");
        cleanup_guard();
        return false;
    }
    
    try {
        // Store callbacks and copy prompt
        h->cbs = cbs;
        h->prompt_copy.assign(prompt_utf8);
        h->modern_mode = true;
        
        // Apply generation parameters
        if (p) {
            epi_set_top_k(40);  // Default top_k
            epi_set_top_p(p->top_p);
            epi_set_temp(p->temperature);
            epi_set_n_predict(p->max_tokens);
        }
        
        // Tokenize into our owned vector
        h->prompt_toks.clear();
        h->prompt_toks.reserve(1024);
        
        const llama_vocab* vocab = llama_model_get_vocab(h->model);
        int add_bos = 1; // Phi models often expect BOS
        int n_tokens = llama_tokenize(vocab, h->prompt_copy.c_str(), h->prompt_copy.size(), 
                                     h->prompt_toks.data(), h->prompt_toks.capacity(), add_bos, true);
        
        if (n_tokens < 0) {
            // Need more space
            h->prompt_toks.resize(-n_tokens);
            n_tokens = llama_tokenize(vocab, h->prompt_copy.c_str(), h->prompt_copy.size(), 
                                     h->prompt_toks.data(), h->prompt_toks.size(), add_bos, true);
        }
        
        if (n_tokens <= 0) {
            epi_logf(3, "epi_start: tokenize failed n_tokens=%d", n_tokens);
            cleanup_guard();
            return false;
        }
        
        // Initialize generation state
        h->n_prompt_tokens = n_tokens;
        h->n_generated = 0;
        h->next_token = 0; // Will be set by first decode
        
        h->prompt_toks.resize(n_tokens);
        epi_logf(1, "epi_start: tokenized %d tokens", n_tokens);
        
        // Clear KV cache
        llama_memory_t mem = llama_get_memory(h->ctx);
        llama_memory_clear(mem, true);
        epi_logf(1, "epi_start: kv cleared");
        
        g_state.store(2, std::memory_order_release);
        h->starting = false; // Reset guard on success
        epi_logf(1, "EXIT epi_start tid=%lu state=%d handle=%p request_id=%llu", 
                 tid(), g_state.load(), g_handle.load(), request_id);
        return true;
        
    } catch (...) {
        epi_logf(3, "unhandled C++ exception in epi_start");
        cleanup_guard();
        return false;
    }
}

bool epi_feed(int n_prompt_tokens, uint64_t request_id) {
    std::lock_guard<std::mutex> lk(g_mu);
    epi_logf(1, "ENTER epi_feed tid=%lu state=%d handle=%p request_id=%llu", 
             tid(), g_state.load(), g_handle.load(), request_id);
    
    auto* h = g_handle.load(std::memory_order_acquire);
    if (!h || !h->modern_mode) {
        epi_logf(3, "epi_feed aborted: handle is null or not in modern mode");
        return false;
    }
    
    // Verify this request is still in flight and matches
    uint64_t current_id = RequestGate::current();
    if (current_id == 0) {
        epi_logf(3, "epi_feed rejected: no request in flight (request_id=%llu)", request_id);
        return false;
    }
    if (current_id != request_id) {
        epi_logf(3, "epi_feed rejected: request %llu not in flight (current: %llu)", 
                 request_id, current_id);
        return false;
    }
    
    // Instance-based re-entrancy guard - prevent duplicate calls
    bool expected = false;
    if (!h->feeding.compare_exchange_strong(expected, true)) {
        epi_logf(3, "epi_feed already in progress - ignoring duplicate call (request_id=%llu)", request_id);
        return false;
    }
    
    try {
        // Feed prompt tokens in chunks using our owned vector
        const int chunk = 256;
        int off = 0;
        static llama_seq_id seq_id = 0;
        
        while (off < (int)h->prompt_toks.size()) {
            const int n = std::min(chunk, (int)h->prompt_toks.size() - off);
            
            // Use RAII pattern for batch management
            llama_batch batch = llama_batch_init(n, /*embd*/0, /*alloc*/1);
            if (!batch.token) {
                epi_logf(3, "epi_feed: batch init failed (off=%d n=%d)", off, n);
                h->feeding = false; // Reset guard
                RequestGate::end(request_id); // Release gate
                return false;
            }
            
            // Scope the batch usage
            {
                for (int i = 0; i < n; ++i) {
                    int pos = off + i;
                    batch.token[batch.n_tokens] = h->prompt_toks[off + i];
                    batch.pos[batch.n_tokens] = pos;
                    batch.n_seq_id[batch.n_tokens] = 1;
                    batch.seq_id[batch.n_tokens] = &seq_id;
                    batch.logits[batch.n_tokens] = (i == n - 1) ? 1 : 0; // Only last token needs logits
                    batch.n_tokens++;
                }
                
                int rc = llama_decode(h->ctx, batch);
                if (rc != 0) {
                    epi_logf(3, "epi_feed: decode failed rc=%d (off=%d n=%d)", rc, off, n);
                    llama_batch_free(batch);
                    h->feeding = false; // Reset guard
                    RequestGate::end(request_id); // Release gate
                    return false;
                }
                epi_logf(1, "epi_feed: off=%d n=%d decode ok", off, n);
            }
            
            // Always free the batch in the same scope where it was allocated
            llama_batch_free(batch);
            off += n;
        }
        
        epi_logf(1, "EXIT epi_feed tid=%lu state=%d handle=%p request_id=%llu", 
                 tid(), g_state.load(), g_handle.load(), request_id);
        h->feeding = false; // Reset guard
        RequestGate::end(request_id); // Release gate
        return true;
        
    } catch (...) {
        epi_logf(3, "unhandled C++ exception in epi_feed");
        h->feeding = false; // Reset guard
        RequestGate::end(request_id); // Release gate
        return false;
    }
}

bool epi_stop(void) {
    std::lock_guard<std::mutex> lk(g_mu);
    epi_logf(1, "ENTER epi_stop tid=%lu state=%d handle=%p", 
             tid(), g_state.load(), g_handle.load());
    
    auto* h = g_handle.load(std::memory_order_acquire);
    if (h && h->modern_mode) {
        // Clear modern API state
        h->prompt_copy.clear();
        h->prompt_toks.clear();
        h->cbs = {nullptr, nullptr};
        h->modern_mode = false;
    }
    
    // Always reset generation flag
    g_generating = false;
    g_state.store(1, std::memory_order_release);
    
    epi_logf(1, "EXIT epi_stop tid=%lu state=%d handle=%p", 
             tid(), g_state.load(), g_handle.load());
    return true;
}

bool epi_llama_generate_next(llama_token_callback_t on_token, void* user_data, bool* out_is_eos) {
    // Simplified for now - just return false
    epi_logf(1, "epi_llama_generate_next called (not implemented)");
    if (out_is_eos) *out_is_eos = true;
    return false;
}

void epi_llama_stop(void) {
    epi_logf(1, "epi_llama_stop called");
}

void epi_set_top_k(int32_t top_k) {
    epi_logf(1, "epi_set_top_k: %d", top_k);
}

void epi_set_top_p(float top_p) {
    epi_logf(1, "epi_set_top_p: %.3f", top_p);
}

void epi_set_temp(float temp) {
    epi_logf(1, "epi_set_temp: %.3f", temp);
}

void epi_set_n_predict(int32_t n_predict) {
    auto* h = g_handle.load(std::memory_order_acquire);
    if (h) {
        h->n_predict = n_predict;
        epi_logf(1, "epi_set_n_predict: %d", n_predict);
    }
}

// Core API generation function - replaces the old decode/take_token approach
extern "C" const char* epi_generate_core_api_impl(const char* prompt_utf8, const epi_gen_params* p, uint64_t request_id) {
    static std::string result;
    std::lock_guard<std::mutex> lk(g_mu);
    auto* h = g_handle.load(std::memory_order_acquire);
    if (!h || !h->modern_mode) {
        result = "";
        return result.c_str();
    }
    
    // Verify request is still in flight
    uint64_t current_id = RequestGate::current();
    if (current_id != request_id) {
        epi_logf(3, "epi_generate_core_api rejected: request %llu not in flight (current: %llu)", 
                 request_id, current_id);
        result = "";
        return result.c_str();
    }
    
    const std::string prompt(prompt_utf8);
    const int32_t max_tokens = p ? p->max_tokens : 256;
    const float temperature = p ? p->temperature : 0.7f;
    const float top_p = p ? p->top_p : 0.9f;
    const float repeat_penalty = p ? p->repeat_penalty : 1.1f;
    const int32_t top_k = 40; // Default top_k
    
    epi_logf(1, "epi_generate_core_api: prompt_len=%zu max_tokens=%d temp=%.2f", 
             prompt.length(), max_tokens, temperature);
    
        // 1) Tokenize prompt using compatibility layer
        auto prompt_tokens = compat_tokenize(h->model, h->ctx, prompt, /*add_bos=*/true, /*parse_special=*/true);
        if (prompt_tokens.empty()) {
            epi_logf(3, "epi_generate_core_api: tokenize failed");
            result = "";
            return result.c_str();
        }
    
    // 2) Evaluate prompt
    llama_batch batch = llama_batch_init(512, 0, 1);
    int32_t n_past = 0;
    int n_prompt = (int)prompt_tokens.size();
    for (int i = 0; i < n_prompt; ++i) {
        batch.n_tokens         = 1;
        batch.token[0]         = prompt_tokens[i];
        batch.pos[0]           = n_past;
        batch.seq_id[0][0]     = 0;
        batch.n_seq_id[0]      = 1;
        batch.logits[0]        = (i == n_prompt - 1); // only last needs logits
        if (llama_decode(h->ctx, batch) != 0) {
            epi_logf(3, "epi_generate_core_api: decode failed at prompt token %d", i);
            llama_batch_free(batch);
            result = "";
            return result.c_str();
        }
        n_past += 1;
    }
    
    // Discover special stop tokens at runtime using compatibility layer
    const auto specials = compat_discover_specials(h->model, h->ctx);
    const llama_token tok_eot = specials.eot;
    const llama_token tok_eom = specials.eos; // Use EOS as EOM fallback
    
    std::string out;
    std::vector<llama_token> last_tokens; 
    last_tokens.reserve(128);
    
    for (int i = 0; i < max_tokens; ++i) {
        // 3) Build candidate list from logits of the last token using compatibility layer
        const int n_vocab = compat_vocab_n_tokens(h->model, h->ctx);
        const float* logits = llama_get_logits(h->ctx);
        std::vector<llama_token_data> cands; 
        cands.reserve(n_vocab);
        for (llama_token t = 0; t < n_vocab; ++t) {
            cands.push_back({ t, logits[t], 0.0f });
        }
        llama_token_data_array cur = { cands.data(), (size_t)cands.size(), false };
        
        // 4) Simple sampling - just pick the highest probability token
        // This avoids the complex sampler chain API issues
        llama_token tok = 0;
        float max_logit = -1e9f;
        for (llama_token t = 0; t < n_vocab; ++t) {
            if (logits[t] > max_logit) {
                max_logit = logits[t];
                tok = t;
            }
        }
        
        // 6) Stop conditions
        if ((tok_eot != -1 && tok == tok_eot) || (tok_eom != -1 && tok == tok_eom)) {
            epi_logf(2, "epi_generate_core_api: stop token reached at %d", i);
            break;
        }
        
        // 7) Convert token piece to text using compatibility layer
        std::string piece = compat_token_to_piece(h->model, h->ctx, tok);
        if (!piece.empty()) {
            out.append(piece);
            epi_logf(2, "epi_generate_core_api: token %d -> '%s'", i, piece.c_str());
        }
        
        // 8) Feed back the new token
        batch.n_tokens         = 1;
        batch.token[0]         = tok;
        batch.pos[0]           = n_past;
        batch.seq_id[0][0]     = 0;
        batch.n_seq_id[0]      = 1;
        batch.logits[0]        = true;
        if (llama_decode(h->ctx, batch) != 0) {
            epi_logf(3, "epi_generate_core_api: decode failed at generation token %d", i);
            break;
        }
        
        last_tokens.push_back(tok);
        n_past += 1;
    }
    
    llama_batch_free(batch);
    epi_logf(1, "epi_generate_core_api: generated %zu chars", out.length());
    result = out;
    return result.c_str();
}

// C wrapper for the core API function
const char* epi_generate_core_api(const char* prompt_utf8, const epi_gen_params* p, uint64_t request_id) {
    static std::string result;
    result = epi_generate_core_api_impl(prompt_utf8, p, request_id);
    return result.c_str();
}

// New compatibility-aware core API implementation
extern "C" bool epi_generate_core_api_impl_new(
    void* model_ptr,
    void* ctx_ptr,
    const char *prompt_utf8,
    int32_t n_predict,
    float temp, int32_t top_k, float top_p, float min_p,
    // output callback: called per token piece
    void (*on_text)(const char *utf8, void *userdata),
    void *userdata,
    // stop flags: set by the loop on exit
    bool *did_stop_n_predict,
    bool *did_hit_eot
) {
    llama_model *model = (llama_model*)model_ptr;
    llama_context *ctx = (llama_context*)ctx_ptr;
    try {
        LLAMA_COMPAT_ASSERT(model && ctx && prompt_utf8 && on_text);
        if (n_predict <= 0) n_predict = 512;

        // 1) specials & sampler
        const auto specials = compat_discover_specials(model, ctx);
        std::unique_ptr<compat_sampler, void(*)(compat_sampler*)>
            sampler(compat_sampler_create(temp, top_k, top_p, min_p), compat_sampler_free);

        // 2) tokenize prompt (allow special tokens so chat templates work)
        const std::string prompt(prompt_utf8);
        auto toks = compat_tokenize(model, ctx, prompt, /*add_bos=*/true, /*parse_special=*/true);
        LLAMA_COMPAT_ASSERT(!toks.empty());

        // 3) evaluate prompt
        {
            llama_batch batch = llama_batch_init(512, 0, 1);
            int pos = 0;
            for (auto t : toks) {
                batch.token[batch.n_tokens] = t;
                batch.pos[batch.n_tokens]   = pos++;
                batch.n_seq_id[batch.n_tokens] = 1;
                batch.seq_id[batch.n_tokens][0] = 0;
                batch.logits[batch.n_tokens] = false;
                batch.n_tokens++;
                if (batch.n_tokens == 512) { // Use fixed capacity
                    if (llama_decode(ctx, batch)) { llama_batch_free(batch); throw std::runtime_error("llama_decode(prompt) failed"); }
                    batch.n_tokens = 0;
                }
            }
            if (batch.n_tokens > 0) {
                if (llama_decode(ctx, batch)) { llama_batch_free(batch); throw std::runtime_error("llama_decode(end prompt) failed"); }
            }
            llama_batch_free(batch);
        }

        // 4) generate
        *did_stop_n_predict = false;
        *did_hit_eot = false;
        int generated = 0;

        for (; generated < n_predict; ++generated) {
            llama_token id = compat_sample_next(model, ctx, sampler.get());

            // Stop checks
            if (id == specials.eos || id == specials.eot) {
                *did_hit_eot = true;
                break;
            }

            // Append & decode this token to advance logits
            {
                llama_batch batch = llama_batch_init(1, 0, 1);
                batch.token[0] = id;
                batch.pos[0]   = (int)toks.size() + generated;
                batch.n_seq_id[0] = 1;
                batch.seq_id[0][0] = 0;
                batch.logits[0] = true;
                batch.n_tokens = 1;
                if (llama_decode(ctx, batch)) { llama_batch_free(batch); throw std::runtime_error("llama_decode(gen) failed"); }
                llama_batch_free(batch);
            }

            std::string piece = compat_token_to_piece(model, ctx, id);
            if (!piece.empty()) on_text(piece.c_str(), userdata);
        }

        if (generated >= n_predict) *did_stop_n_predict = true;
        return true;
    } catch (const std::exception &e) {
        // Map to your error surface if needed
        return false;
    }
}

// Legacy functions for compatibility - now just call the core API
bool epi_decode(uint64_t request_id) {
    // This is now handled internally by epi_generate_core_api
    return true;
}

int32_t epi_take_token(uint64_t request_id) {
    // This is now handled internally by epi_generate_core_api
    return 0;
}

const char* epi_decode_to_text(int32_t token_id) {
    // This is now handled internally by epi_generate_core_api
    return "";
}

bool epi_is_eos_token(int32_t token_id) {
    // This is now handled internally by epi_generate_core_api
    return false;
}

} // extern "C"
