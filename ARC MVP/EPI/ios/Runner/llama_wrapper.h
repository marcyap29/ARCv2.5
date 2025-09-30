// llama_wrapper.h
// Header file for llama.cpp wrapper functions

#ifndef llama_wrapper_h
#define llama_wrapper_h

#ifdef __cplusplus
extern "C" {
#endif

// Initialize the model
int32_t llama_init(const char* modelPath);

// Generate text using the model
const char* llama_generate(const char* prompt, float temperature, float topP, int32_t maxTokens);

// Clean up resources
void llama_cleanup();

// Check if model is loaded
int32_t llama_is_loaded();

#ifdef __cplusplus
}
#endif

#endif /* llama_wrapper_h */
