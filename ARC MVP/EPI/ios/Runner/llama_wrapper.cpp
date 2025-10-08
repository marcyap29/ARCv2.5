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
    epi_logf(1, "EXIT  init tid=%lu state=%d handle=%p SUCCESS", 
             tid(), g_state.load(), g_handle);
    
    return true;
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
    if (!g_handle) {
        epi_logf(3, "start aborted: handle is null");
        return false;
    }
    
    // Clear memory
    llama_memory_t mem = llama_get_memory(g_handle->ctx);
    if (mem) {
        llama_memory_clear(mem, true);
    }
    
    // Get vocab for tokenization
    const llama_vocab* vocab = llama_model_get_vocab(g_handle->model);
    if (!vocab) return false;
    
    // Tokenize prompt
    int needed = llama_tokenize(vocab, prompt_utf8, strlen(prompt_utf8), nullptr, 0, true, true);
    if (needed <= 0) return false;
    
    std::vector<llama_token> toks(needed);
    int n = llama_tokenize(vocab, prompt_utf8, strlen(prompt_utf8), toks.data(), needed, true, true);
    if (n <= 0) return false;
    
    // Reset batch
    g_handle->batch.n_tokens = 0;
    
    // Add prompt tokens to batch manually
    static llama_seq_id seq_id = 0; // Single sequence ID
    for (int i = 0; i < n; ++i) {
        if (g_handle->batch.n_tokens >= 512) break; // Safety check
        
        int idx = g_handle->batch.n_tokens;
        g_handle->batch.token[idx] = toks[i];
        g_handle->batch.pos[idx] = i;
        g_handle->batch.n_seq_id[idx] = 1;
        g_handle->batch.seq_id[idx] = &seq_id; // Point to single sequence ID
        g_handle->batch.logits[idx] = (i == n - 1) ? 1 : 0; // Only last token needs logits
        g_handle->batch.n_tokens++;
    }
    
    // Decode prompt
    if (llama_decode(g_handle->ctx, g_handle->batch) != 0) {
        epi_logf(3, "start failed: llama_decode returned error");
        return false;
    }
    
    g_handle->started = true;
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