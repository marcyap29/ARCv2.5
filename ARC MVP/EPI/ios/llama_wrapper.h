// llama_wrapper.h
// Header file for llama.cpp wrapper functions with Metal support

#ifndef llama_wrapper_h
#define llama_wrapper_h

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Model initialization and management
int32_t llama_init(const char* modelPath);
int32_t llama_is_loaded();
void llama_cleanup();

// Text generation with streaming support
const char* llama_generate(const char* prompt, float temperature, float topP, int32_t maxTokens);

// Streaming generation (new API)
typedef struct {
    const char* token;
    bool is_finished;
    int32_t error_code;
} llama_stream_result_t;

// Initialize streaming generation
int32_t llama_start_generation(const char* prompt, float temperature, float topP, int32_t maxTokens);

// Get next token in stream
llama_stream_result_t llama_get_next_token();

// Cancel current generation
void llama_cancel_generation();

// Model information
const char* llama_get_model_info();
int32_t llama_get_context_length();

#ifdef __cplusplus
}
#endif

#endif /* llama_wrapper_h */
