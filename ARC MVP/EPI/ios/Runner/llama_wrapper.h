#pragma once
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Token callback: called with a UTF-8 piece whenever a token is produced
typedef void(*llama_token_callback_t)(const char* utf8_token, void* user_data);

// Initialize model and context
// model_path: absolute or app-bundle resolved path to .gguf
// ctx_size_tokens: KV cache size in tokens
// n_gpu_layers: set >0 to offload layers to GPU when supported
bool epi_llama_init(const char* model_path, int32_t ctx_size_tokens, int32_t n_gpu_layers);

// Free resources
void epi_llama_free(void);

// Start a generation with a prompt. Returns false if context is missing or tokenize fails.
bool epi_llama_start(const char* prompt_utf8);

// Generate next token. Streams token via callback. Sets out_is_eos when EOS is reached.
bool epi_llama_generate_next(llama_token_callback_t on_token, void* user_data, bool* out_is_eos);

// Stop current generation loop
void epi_llama_stop(void);

// Optional simple sampler controls
void epi_set_top_k(int32_t top_k);
void epi_set_top_p(float top_p);
void epi_set_temp(float temperature);

// Logger setup
void epi_set_logger(void (*logger)(int level, const char* msg));

#ifdef __cplusplus
}
#endif