#pragma once
#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>


#ifdef __cplusplus
extern "C" {
#endif

// Token callback: called with a UTF-8 piece whenever a token is produced
typedef void(*llama_token_callback_t)(const char* utf8_token, void* user_data);

// Callback bundle for streaming
typedef struct {
  llama_token_callback_t on_token;
  void*                  user;
} epi_callbacks;

// Generation parameters
typedef struct {
  int   max_tokens;
  float temperature;
  float top_p;
  float repeat_penalty;
} epi_gen_params;

// Initialize model and context
// model_path: absolute or app-bundle resolved path to .gguf
// ctx_size_tokens: KV cache size in tokens
// n_gpu_layers: set >0 to offload layers to GPU when supported
bool epi_llama_init(const char* model_path, int32_t ctx_size_tokens, int32_t n_gpu_layers);

// Free resources
void epi_llama_free(void);

// Start a generation with a prompt. Returns false if context is missing or tokenize fails.
bool epi_llama_start(const char* prompt_utf8);

// Start generation with CPU fallback if GPU fails
bool epi_llama_start_with_fallback(const char* prompt_utf8);

// Generate next token. Streams token via callback. Sets out_is_eos when EOS is reached.
bool epi_llama_generate_next(llama_token_callback_t on_token, void* user_data, bool* out_is_eos);

// Stop current generation loop
void epi_llama_stop(void);

// Modern streaming API (ownership rules: callee NEVER frees caller pointers)
// - start(): callee COPIES prompt and stores cbs. Returns when ready to feed.
// - feed():  decodes the copied prompt in internal batches; n_prompt_tokens is ignored if callee tokenized.
// - stop():  finalizes generation and clears internal buffers.
bool epi_start(const char* prompt_utf8, const epi_gen_params* p, epi_callbacks cbs, uint64_t request_id);
bool epi_feed(int n_prompt_tokens, uint64_t request_id);
bool epi_stop(void);
void RequestGate_end(uint64_t request_id);
uint64_t RequestGate_current(void);

// Optional simple sampler controls
void epi_set_top_k(int32_t top_k);
void epi_set_top_p(float top_p);
void epi_set_temp(float temperature);
void epi_set_n_predict(int32_t n_predict);

// Core API generation function
const char* epi_generate_core_api(const char* prompt_utf8, const epi_gen_params* p, uint64_t request_id);

// New compatibility-aware core API implementation
bool epi_generate_core_api_impl_new(
    void* model,
    void* ctx,
    const char *prompt_utf8,
    int32_t n_predict,
    float temp, int32_t top_k, float top_p, float min_p,
    void (*on_text)(const char *utf8, void *userdata),
    void *userdata,
    bool *did_stop_n_predict,
    bool *did_hit_eot
);

// Legacy functions for compatibility
bool epi_decode(uint64_t request_id);
int32_t epi_take_token(uint64_t request_id);
const char* epi_decode_to_text(int32_t token_id);
bool epi_is_eos_token(int32_t token_id);

// Logger setup
void epi_set_logger(void (*logger)(int level, const char* msg));



#ifdef __cplusplus
}
#endif