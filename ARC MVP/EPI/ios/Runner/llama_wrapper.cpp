#include "llama_wrapper.h"
#include "epi_logger.h"
#include "llama.h"
#include <vector>
#include <string>
#include <cstring>
#include <algorithm>
#include <cassert>
#include <atomic>
#include <mutex>
#include <thread>
#include <signal.h>

// Modern handle-based approach
struct epi_handle_t {
    llama_model *   model  = nullptr;
    llama_context * ctx    = nullptr;
    llama_batch     batch  = {};
    int32_t         n_vocab = 0;
    bool            started = false;
    void*           sampler = nullptr;  // Will be llama_sampler_t when available
};

// Global state
static std::atomic<epi_handle_t*> g_handle{nullptr};
static std::atomic<int> g_state{0}; // 0=Uninit,1=Init,2=Running
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
        llama_batch_free(batch);
        if (rc != 0) {
            epi_logf(3, "feed: decode failed rc=%d (off=%d n=%d)", rc, off, n);
            return -30;
        }
        epi_logf(1, "feed: off=%d n=%d decode ok", off, n);
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
        llama_batch_free(batch);
        if (rc != 0) {
            epi_logf(3, "gen: decode rc=%d at produced=%d", rc, produced);
            return -31;
        }

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
    
    g_handle.store(h, std::memory_order_release);
    g_state.store(1, std::memory_order_release);
    
#if defined(LLAMA_METAL)
    epi_logf(1, "metal: compiled in");
#else
    epi_logf(1, "metal: not compiled");
#endif
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
    
    int code = -99;
    try {
        code = start_core(g_handle.load(std::memory_order_acquire), prompt_utf8);
    } catch (...) {
        epi_logf(3, "unhandled C++ exception in start_core");
        code = -98;
    }
    
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



} // extern "C"
