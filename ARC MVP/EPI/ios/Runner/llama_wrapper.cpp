#include "llama_wrapper.h"
#include "llama.h"
#include "epi_logger.h"
#include <vector>
#include <string>
#include <cstring>
#include <algorithm>
#include <cassert>
#include <mutex>
#include <atomic>
#include <thread>

// Modern handle-based approach
struct epi_handle_t {
    llama_model *   model  = nullptr;
    llama_context * ctx    = nullptr;
    llama_batch     batch  = {};
    int32_t         n_vocab = 0;
    bool            started = false;
    void*           sampler = nullptr;  // Will be llama_sampler_t when available
};

// Global state for backward compatibility
static epi_handle_t* g_handle = nullptr;
static std::mutex g_mu;
static std::atomic<int> g_state{0}; // 0=Uninit,1=Init,2=Running

static inline unsigned long tid() {
#if defined(__APPLE__)
    uint64_t id;
    pthread_threadid_np(nullptr, &id);
    return (unsigned long)id;
#else
    return (unsigned long)std::hash<std::thread::id>{}(std::this_thread::get_id());
#endif
}

// Simple greedy sampling
static llama_token sample_from_logits(const float* logits, int32_t n_vocab) {
    llama_token best = 0;
    float bestv = logits[0];
    for (int32_t i = 1; i < n_vocab; ++i) {
        if (logits[i] > bestv) { 
            bestv = logits[i]; 
            best = i; 
        }
    }
    return best;
}

extern "C" {

bool epi_llama_init(const char* model_path, int32_t ctx_size_tokens, int32_t n_gpu_layers) {
    std::lock_guard<std::mutex> lk(g_mu);
    epi_logf(1, "ENTER init tid=%lu state=%d handle=%p path=%s ctx=%d gpu=%d", 
             tid(), g_state.load(), g_handle, model_path, ctx_size_tokens, n_gpu_layers);
    
    // Clean up existing handle
    if (g_handle) {
        epi_logf(1, "Cleaning up existing handle");
        epi_llama_free();
    }
    
            llama_backend_init();
    
    llama_model_params mparams = llama_model_default_params();
    mparams.n_gpu_layers = n_gpu_layers;
    llama_model * model = llama_load_model_from_file(model_path, mparams);
    if (!model) return false;
    
    llama_context_params cparams = llama_context_default_params();
    cparams.n_ctx = ctx_size_tokens;
    
    llama_context * ctx = llama_new_context_with_model(model, cparams);
    if (!ctx) {
        llama_free_model(model);
        return false;
    }
    
    g_handle = new epi_handle_t();
    g_handle->model = model;
    g_handle->ctx = ctx;
    g_handle->batch = llama_batch_init(512, 0, 1);
    // Get vocab size from the vocab
    const llama_vocab* vocab = llama_model_get_vocab(model);
    g_handle->n_vocab = vocab ? llama_vocab_n_tokens(vocab) : 0;
    g_handle->started = false;
    
    g_state.store(1, std::memory_order_release);
    
#if defined(LLAMA_METAL)
    epi_logf(1, "metal: compiled in");
            #else
    epi_logf(1, "metal: not compiled");
            #endif
    epi_logf(1, "gpu layers requested=%d", n_gpu_layers);
    
    epi_logf(1, "EXIT  init tid=%lu state=%d handle=%p SUCCESS", 
             tid(), g_state.load(), g_handle);
    
    return true;
}

// CPU fallback function
bool epi_llama_start_with_fallback(const char* prompt_utf8) {
    // Try with current settings first
    if (epi_llama_start(prompt_utf8)) {
        return true;
    }
    
    epi_logf(2, "retrying with CPU fallback (n_gpu_layers=0)");
    
    // Store current params
    int32_t current_ctx = 2048; // We'll need to track this
    int32_t current_gpu = 16;   // We'll need to track this
    
    // Free current handle
    epi_llama_free();
    
    // Reinit with CPU only - we need the model path, not the model pointer
    // For now, just return false since we don't have the path stored
    epi_logf(3, "CPU fallback not implemented - need model path");
    return false;
}

void epi_llama_free(void) {
    std::lock_guard<std::mutex> lk(g_mu);
    epi_logf(1, "ENTER free  tid=%lu state=%d handle=%p", 
             tid(), g_state.load(), g_handle);
    if (g_handle) {
        llama_batch_free(g_handle->batch);
        llama_free(g_handle->ctx);
        llama_free_model(g_handle->model);
        delete g_handle;
        g_handle = nullptr;
    }
    g_state.store(0, std::memory_order_release);
                llama_backend_free();
    epi_logf(1, "EXIT  free  tid=%lu state=%d handle=%p", 
             tid(), g_state.load(), g_handle);
}

bool epi_llama_start(const char* prompt_utf8) {
    std::lock_guard<std::mutex> lk(g_mu);
    epi_logf(1, "ENTER start tid=%lu state=%d handle=%p", 
             tid(), g_state.load(), g_handle);
    
    auto* h = g_handle;
    if (!h) {
        epi_logf(3, "start aborted: handle is null");
        return false;
    }

    if (!prompt_utf8 || *prompt_utf8 == 0) {
        epi_logf(3, "start aborted: empty prompt");
        return false;
    }
    size_t prompt_len = strlen(prompt_utf8);
    epi_logf(1, "start: prompt bytes=%zu", prompt_len);

    // 1) Robust tokenization (two-pass)
    std::vector<llama_token> toks;
    {
        const llama_vocab* vocab = llama_model_get_vocab(h->model);
        if (!vocab) {
            epi_logf(3, "tokenize failed: no vocab");
            return -10;  // Specific error code
        }
        
        bool add_bos = true;  // Phi models often expect BOS
        bool parse_special = true;
        
        // First call with null to get needed size (returned as negative)
        int needed = llama_tokenize(vocab, prompt_utf8, prompt_len, nullptr, 0, add_bos ? 1 : 0, parse_special ? 1 : 0);
        if (needed == 0) {
            epi_logf(3, "tokenize failed: empty input");
            return -3;  // Empty prompt
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
            return -10;  // Tokenization produced 0 tokens
        }
        toks.resize(n);
        
        epi_logf(1, "tokenize ok: n_tokens=%d head=[%d,%d,%d...]",
                 n, toks[0], toks.size()>1?toks[1]:-1, toks.size()>2?toks[2]:-1);
        
        int n_ctx = llama_n_ctx(h->ctx);
        if (n >= n_ctx) {
            epi_logf(2, "warn: tokens=%d exceed/meet ctx=%d; truncating head", n, n_ctx);
            toks.resize(n_ctx - 1);  // leave room for at least 1 generated token
        }
    }

    // 2) Clear memory
    llama_memory_t mem = llama_get_memory(h->ctx);
    if (mem) {
        llama_memory_clear(mem, true);
        epi_logf(1, "memory cleared");
    }

    // 3) Create batch for first decode
    int n_seed = std::min((int)toks.size(), 512);  // Limit to 512 for safety
    llama_batch batch = llama_batch_init(n_seed, 0, 1);
    if (!batch.token) {
        epi_logf(3, "llama_batch_init failed");
        return -20;  // Batch init failed
    }
    
    // 4) Add prompt tokens to batch manually
    static llama_seq_id seq_id = 0; // Single sequence ID
    for (int i = 0; i < n_seed; ++i) {
        int idx = batch.n_tokens;
        batch.token[idx] = toks[i];
        batch.pos[idx] = i;
        batch.n_seq_id[idx] = 1;
        batch.seq_id[idx] = &seq_id; // Point to single sequence ID
        batch.logits[idx] = (i == n_seed - 1) ? 1 : 0; // Only last token needs logits
        batch.n_tokens++;
    }
    epi_logf(1, "batch ok: n_tokens=%d", batch.n_tokens);

    // 5) First decode
    int dec = llama_decode(h->ctx, batch);
    if (dec != 0) {
        epi_logf(3, "llama_decode failed: code=%d (gpu_layers=%d)",
                 dec, h->model ? llama_model_n_layer(h->model) : -1);
        llama_batch_free(batch);
        return -30;  // First decode failed
    }
    epi_logf(1, "decode ok: first step");
    
    // 6) Clean up temporary batch
    llama_batch_free(batch);
    
    // 7) Feed remaining prompt tokens in chunks
    int remaining = (int)toks.size() - n_seed;
    if (remaining > 0) {
        epi_logf(1, "feeding remaining %d tokens in chunks", remaining);
        int off = n_seed;
        const int chunk_size = 256;
        
        while (off < (int)toks.size()) {
            int n = std::min(chunk_size, (int)toks.size() - off);
            
            llama_batch chunk_batch = llama_batch_init(n, 0, 1);
            if (!chunk_batch.token) {
                epi_logf(3, "chunk batch init failed at off=%d", off);
                return -20;
            }
            
            for (int i = 0; i < n; ++i) {
                int pos = off + i;
                chunk_batch.token[chunk_batch.n_tokens] = toks[off + i];
                chunk_batch.pos[chunk_batch.n_tokens] = pos;
                chunk_batch.n_seq_id[chunk_batch.n_tokens] = 1;
                chunk_batch.seq_id[chunk_batch.n_tokens] = &seq_id;
                chunk_batch.logits[chunk_batch.n_tokens] = (i == n - 1) ? 1 : 0; // Last token needs logits
                chunk_batch.n_tokens++;
            }
            
            int rc = llama_decode(h->ctx, chunk_batch);
            llama_batch_free(chunk_batch);
            if (rc != 0) {
                epi_logf(3, "chunk decode failed: code=%d at off=%d n=%d", rc, off, n);
                return -30;
            }
            
            epi_logf(1, "chunk: off=%d n=%d decode ok", off, n);
            off += n;
        }
    }
    
    epi_logf(1, "prompt ingest complete: %d total tokens", (int)toks.size());
    
    // 8) Sampler initialization (simplified for now)
    // Note: llama_sampler_init may not be available in this llama.cpp version
    // We'll use simple greedy sampling for now
    epi_logf(1, "using simple greedy sampling");
    
    // 9) Generate tokens (simplified for now - just sample one token)
    const float* logits = llama_get_logits_ith(h->ctx, 0);
    if (!logits) {
        epi_logf(3, "no logits available for sampling");
        return -50;
    }
    
    // Simple greedy sampling for now
    int32_t best_token = 0;
    float best_logit = logits[0];
    int32_t n_vocab = llama_vocab_n_tokens(llama_model_get_vocab(h->model));
    for (int32_t i = 1; i < n_vocab; ++i) {
        if (logits[i] > best_logit) {
            best_logit = logits[i];
            best_token = i;
        }
    }
    
    epi_logf(1, "sampled token: %d (logit=%.3f)", best_token, best_logit);
    
    // 10) Prepare for next generation step
    h->batch.n_tokens = 0;
    h->started = true;
    g_state.store(2, std::memory_order_release);
    
    epi_logf(1, "EXIT  start tid=%lu state=%d handle=%p SUCCESS", 
             tid(), g_state.load(), g_handle);
    return true;
}

bool epi_llama_generate_next(llama_token_callback_t on_token, void* user_data, bool* out_is_eos) {
    std::lock_guard<std::mutex> lk(g_mu);
    if (!g_handle || !g_handle->started) return false;
    
    // Get logits for the last decoded token
    const float* logits = llama_get_logits_ith(g_handle->ctx, 0);
    if (!logits) return false;
    
    // Sample next token
    llama_token token = sample_from_logits(logits, g_handle->n_vocab);
    
    // Get vocab for detokenization
    const llama_vocab* vocab = llama_model_get_vocab(g_handle->model);
    if (!vocab) return false;
    
    // Convert token to text
    char buf[512];
    int n = llama_detokenize(vocab, &token, 1, buf, sizeof(buf), false, false);
    if (n < 0) return false;
    
    // Call callback
    if (on_token) on_token(buf, user_data);
    
    // Check for EOS
    const int eos = llama_vocab_eos(vocab);
    if (token == eos) {
        if (out_is_eos) *out_is_eos = true;
        return true;
    }
    
    // Prepare next decode step
    static llama_seq_id seq_id = 0; // Single sequence ID
    g_handle->batch.n_tokens = 0;
    g_handle->batch.token[0] = token;
    g_handle->batch.pos[0] = g_handle->batch.n_tokens; // Use current position
    g_handle->batch.n_seq_id[0] = 1;
    g_handle->batch.seq_id[0] = &seq_id; // Point to single sequence ID
    g_handle->batch.logits[0] = 1; // Request logits for this token
    g_handle->batch.n_tokens = 1;
    
    // Decode next step
    if (llama_decode(g_handle->ctx, g_handle->batch) != 0) return false;
    
    if (out_is_eos) *out_is_eos = false;
    return true;
}

void epi_llama_stop(void) {
    std::lock_guard<std::mutex> lk(g_mu);
    if (g_handle) {
        g_handle->started = false;
    }
}

// Simple sampler controls (not implemented in this minimal version)
void epi_set_top_k(int32_t top_k) {
    // TODO: Implement if needed
}

void epi_set_top_p(float top_p) {
    // TODO: Implement if needed
}

void epi_set_temp(float temperature) {
    // TODO: Implement if needed
}

} // extern "C"