// llama_wrapper.cpp
// Simplified llama.cpp integration for iOS MVP
// This provides basic C functions that QwenBridge.swift expects

#include "llama_wrapper.h"
#include "llama.h"
#include <iostream>
#include <string>
#include <memory>
#include <vector>
#include <thread>
#include <atomic>
#include <fstream>

// Global state for the model
static llama_model* g_model = nullptr;
static llama_context* g_context = nullptr;
static std::string current_model_path;
static std::atomic<bool> model_loaded{false};
static std::atomic<bool> generation_active{false};

// Streaming state
static std::vector<llama_token> current_tokens;
static size_t current_token_index = 0;
static std::string current_response;
static std::atomic<bool> stream_finished{false};

// Additional streaming state
static std::string current_prompt;
static float current_temperature = 0.7f;
static float current_top_p = 0.9f;
static int32_t current_max_tokens = 256;
static llama_batch* current_batch = nullptr;

extern "C" {
    // Initialize the model
    int32_t llama_init(const char* modelPath) {
        std::cout << "========================================" << std::endl;
        std::cout << "llama_wrapper: llama_init() CALLED" << std::endl;
        std::cout << "========================================" << std::endl;

        if (!modelPath) {
            std::cout << "llama_wrapper: ERROR - Model path is null" << std::endl;
            return 0;
        }

        current_model_path = std::string(modelPath);
        std::cout << "llama_wrapper: Model path: " << current_model_path << std::endl;

        // Check if file exists
        std::cout << "llama_wrapper: Checking if file exists..." << std::endl;
        std::ifstream file(modelPath);
        if (!file.good()) {
            std::cout << "llama_wrapper: ERROR - Model file does not exist or is not readable" << std::endl;
            return 0;
        }
        file.close();
        std::cout << "llama_wrapper: ✓ File exists and is readable" << std::endl;

        try {
            // Initialize llama.cpp backend
            std::cout << "llama_wrapper: Calling llama_backend_init()..." << std::endl;
            llama_backend_init();
            std::cout << "llama_wrapper: ✓ Backend initialized successfully" << std::endl;

            // Load model with Metal support
            std::cout << "llama_wrapper: Getting default model params..." << std::endl;
            llama_model_params model_params = llama_model_default_params();

            // Check if Metal is available
            #if TARGET_IPHONE_SIMULATOR
            std::cout << "llama_wrapper: Running on SIMULATOR - Metal may have limited support" << std::endl;
            #else
            std::cout << "llama_wrapper: Running on DEVICE - Full Metal support available" << std::endl;
            #endif

            std::cout << "llama_wrapper: ✓ Model params created" << std::endl;

            std::cout << "llama_wrapper: Calling llama_model_load_from_file()..." << std::endl;
            std::cout << "llama_wrapper: This may take 30-60 seconds for large models..." << std::endl;
            g_model = llama_model_load_from_file(modelPath, model_params);

            if (!g_model) {
                std::cout << "llama_wrapper: ERROR - llama_model_load_from_file() returned nullptr" << std::endl;
                std::cout << "llama_wrapper: This usually means:" << std::endl;
                std::cout << "llama_wrapper:   1. GGUF file is corrupted" << std::endl;
                std::cout << "llama_wrapper:   2. Not enough memory" << std::endl;
                std::cout << "llama_wrapper:   3. Incompatible GGUF format" << std::endl;
                llama_backend_free();
                return 0;
            }

            std::cout << "llama_wrapper: ✓ Model loaded successfully!" << std::endl;

            // Create context with Metal backend
            std::cout << "llama_wrapper: Creating context with Metal backend..." << std::endl;
            llama_context_params context_params = llama_context_default_params();
            context_params.n_ctx = 2048;  // Context length
            context_params.n_batch = 512; // Batch size

            #if TARGET_IPHONE_SIMULATOR
            context_params.n_threads = 2; // Use fewer threads on simulator
            context_params.n_gpu_layers = 0; // Disable GPU offloading on simulator
            std::cout << "llama_wrapper: Simulator mode: n_threads=2, GPU layers=0" << std::endl;
            #else
            context_params.n_threads = 4; // Number of threads
            context_params.n_gpu_layers = 99; // Offload all layers to Metal on device
            std::cout << "llama_wrapper: Device mode: n_threads=4, GPU layers=99 (full Metal)" << std::endl;
            #endif

            std::cout << "llama_wrapper: Context params: n_ctx=2048, n_batch=512, n_threads=4, offload_kqv=true" << std::endl;
            std::cout << "llama_wrapper: Calling llama_init_from_model()..." << std::endl;
            g_context = llama_init_from_model(g_model, context_params);

            if (!g_context) {
                std::cout << "llama_wrapper: ERROR - llama_init_from_model() returned nullptr" << std::endl;
                std::cout << "llama_wrapper: This usually means:" << std::endl;
                std::cout << "llama_wrapper:   1. Not enough memory for context" << std::endl;
                std::cout << "llama_wrapper:   2. Invalid context parameters" << std::endl;
                llama_model_free(g_model);
                g_model = nullptr;
                llama_backend_free();
                return 0;
            }

            std::cout << "llama_wrapper: ✓ Context created successfully!" << std::endl;

            model_loaded = true;
            std::cout << "========================================" << std::endl;
            std::cout << "llama_wrapper: ✓✓✓ INITIALIZATION COMPLETE ✓✓✓" << std::endl;
            std::cout << "llama_wrapper: Model ready for inference with Metal acceleration" << std::endl;
            std::cout << "========================================" << std::endl;
            return 1; // Success

        } catch (const std::exception& e) {
            std::cout << "llama_wrapper: EXCEPTION during initialization: " << e.what() << std::endl;
            llama_cleanup();
            return 0;
        } catch (...) {
            std::cout << "llama_wrapper: UNKNOWN EXCEPTION during initialization" << std::endl;
            llama_cleanup();
            return 0;
        }
    }
    
    // Generate text using the model (simplified non-streaming)
    const char* llama_generate(const char* prompt, float temperature, float topP, int32_t maxTokens) {
        if (!model_loaded || !g_model || !g_context) {
            std::cout << "llama_wrapper: Model not loaded" << std::endl;
            return nullptr;
        }
        
        if (!prompt) {
            std::cout << "llama_wrapper: Prompt is null" << std::endl;
            return nullptr;
        }
        
        std::cout << "llama_wrapper: Generating text for prompt: " << std::string(prompt).substr(0, 50) << "..." << std::endl;
        
        try {
            // Real llama.cpp generation
            std::string response;
            
            // Set generation parameters
            llama_batch batch = llama_batch_init(512, 0, 1);
            
            // Tokenize the prompt
            std::vector<llama_token> tokens_list;
            tokens_list = llama_tokenize(g_model, prompt, true);
            
            // Add tokens to batch
            for (size_t i = 0; i < tokens_list.size(); i++) {
                llama_batch_add(batch, tokens_list[i], i, {0}, true);
            }
            
            // Mark the last token as the start of generation
            batch.token[batch.n_tokens - 1] = true;
            
            // Process the batch
            if (llama_decode(g_context, batch) != 0) {
                std::cout << "llama_wrapper: Failed to decode prompt" << std::endl;
                llama_batch_free(batch);
                return nullptr;
            }
            
            // Generate tokens
            int max_tokens = 256; // Default max tokens
            for (int i = 0; i < max_tokens; i++) {
                llama_token new_token_id = 0;
                
                // Sample the next token
                auto logits = llama_get_logits_ith(g_context, batch.n_tokens - 1);
                auto n_vocab = llama_n_vocab(g_model);
                
                // Simple greedy sampling (can be improved with temperature/top_p)
                float max_logit = logits[0];
                for (int j = 1; j < n_vocab; j++) {
                    if (logits[j] > max_logit) {
                        max_logit = logits[j];
                        new_token_id = j;
                    }
                }
                
                // Check for end of sequence
                if (new_token_id == llama_token_eos(g_model)) {
                    break;
                }
                
                // Convert token to string
                char token_str[256];
                int n_chars = llama_token_to_piece(g_model, new_token_id, token_str, sizeof(token_str), false);
                if (n_chars > 0) {
                    response += std::string(token_str, n_chars);
                }
                
                // Prepare next batch
                llama_batch_clear(batch);
                llama_batch_add(batch, new_token_id, batch.n_tokens, {0}, true);
                
                // Decode the new token
                if (llama_decode(g_context, batch) != 0) {
                    std::cout << "llama_wrapper: Failed to decode token" << std::endl;
                    break;
                }
            }
            
            llama_batch_free(batch);
            
            // Return a copy that won't be deallocated
            static char* response_cstr = nullptr;
            if (response_cstr) {
                free(response_cstr);
            }
            response_cstr = (char*)malloc(response.length() + 1);
            strcpy(response_cstr, response.c_str());
            
            return response_cstr;
            
        } catch (const std::exception& e) {
            std::cout << "llama_wrapper: Exception during generation: " << e.what() << std::endl;
            return nullptr;
        }
    }
    
    // Start streaming generation (simplified)
    int32_t llama_start_generation(const char* prompt, float temperature, float topP, int32_t maxTokens) {
        if (!model_loaded || !g_model || !g_context) {
            return 0;
        }
        
        if (generation_active) {
            llama_cancel_generation();
        }
        
        try {
            // Initialize streaming state
            current_tokens.clear();
            current_token_index = 0;
            current_response.clear();
            stream_finished = false;
            generation_active = true;
            
            // Store the prompt and parameters for streaming generation
            current_prompt = std::string(prompt);
            current_temperature = temperature;
            current_top_p = topP;
            current_max_tokens = maxTokens;
            
            // Initialize batch for streaming
            current_batch = llama_batch_init(512, 0, 1);
            
            // Tokenize the prompt
            current_tokens = llama_tokenize(g_model, prompt, true);
            
            // Add tokens to batch
            for (size_t i = 0; i < current_tokens.size(); i++) {
                llama_batch_add(current_batch, current_tokens[i], i, {0}, true);
            }
            
            // Mark the last token as the start of generation
            current_batch->token[current_batch->n_tokens - 1] = true;
            
            // Process the initial batch
            if (llama_decode(g_context, *current_batch) != 0) {
                std::cout << "llama_wrapper: Failed to decode prompt for streaming" << std::endl;
                generation_active = false;
                return 0;
            }
            
            return 1;
            
        } catch (const std::exception& e) {
            std::cout << "llama_wrapper: Exception during stream start: " << e.what() << std::endl;
            return 0;
        }
    }
    
    // Get next token in stream (simplified)
    llama_stream_result_t llama_get_next_token() {
        llama_stream_result_t result = {nullptr, false, 0};
        
        if (!generation_active || stream_finished) {
            result.is_finished = true;
            return result;
        }
        
        try {
            // Real token generation
            if (current_batch == nullptr) {
                result.is_finished = true;
                return result;
            }
            
            // Check if we've reached max tokens
            if (current_token_index >= current_max_tokens) {
                stream_finished = true;
                generation_active = false;
                result.is_finished = true;
                return result;
            }
            
            // Sample the next token
            llama_token new_token_id = 0;
            auto logits = llama_get_logits_ith(g_context, current_batch->n_tokens - 1);
            auto n_vocab = llama_n_vocab(g_model);
            
            // Simple greedy sampling (can be improved with temperature/top_p)
            float max_logit = logits[0];
            for (int j = 1; j < n_vocab; j++) {
                if (logits[j] > max_logit) {
                    max_logit = logits[j];
                    new_token_id = j;
                }
            }
            
            // Check for end of sequence
            if (new_token_id == llama_token_eos(g_model)) {
                stream_finished = true;
                generation_active = false;
                result.is_finished = true;
                return result;
            }
            
            // Convert token to string
            char token_str[256];
            int n_chars = llama_token_to_piece(g_model, new_token_id, token_str, sizeof(token_str), false);
            
            if (n_chars > 0) {
                std::string token_string(token_str, n_chars);
                current_response += token_string;
                
                // Return a copy that won't be deallocated
                static char* token_cstr = nullptr;
                if (token_cstr) {
                    free(token_cstr);
                }
                token_cstr = (char*)malloc(token_string.length() + 1);
                strcpy(token_cstr, token_string.c_str());
                
                result.token = token_cstr;
            }
            
            // Prepare next batch
            llama_batch_clear(*current_batch);
            llama_batch_add(*current_batch, new_token_id, current_batch->n_tokens, {0}, true);
            
            // Decode the new token
            if (llama_decode(g_context, *current_batch) != 0) {
                std::cout << "llama_wrapper: Failed to decode token during streaming" << std::endl;
                stream_finished = true;
                generation_active = false;
                result.is_finished = true;
                return result;
            }
            
            current_token_index++;
            
        } catch (const std::exception& e) {
            std::cout << "llama_wrapper: Exception during stream: " << e.what() << std::endl;
            result.error_code = -1;
            stream_finished = true;
            generation_active = false;
        }
        
        return result;
    }
    
    // Cancel current generation
    void llama_cancel_generation() {
        generation_active = false;
        stream_finished = true;
        current_tokens.clear();
        current_token_index = 0;
        current_response.clear();
        
        // Clean up batch
        if (current_batch) {
            llama_batch_free(*current_batch);
            delete current_batch;
            current_batch = nullptr;
        }
    }
    
    // Get model information
    const char* llama_get_model_info() {
        if (!g_model) {
            return "Model not loaded";
        }
        
        static std::string info = "Model: " + current_model_path + " (Metal accelerated)";
        return info.c_str();
    }
    
    // Get context length
    int32_t llama_get_context_length() {
        if (!g_context) {
            return 0;
        }
        return llama_n_ctx(g_context);
    }
    
    // Clean up resources
    void llama_cleanup() {
        std::cout << "llama_wrapper: Cleaning up resources" << std::endl;
        
        llama_cancel_generation();
        
        if (g_context) {
            llama_free(g_context);
            g_context = nullptr;
        }
        
        if (g_model) {
            llama_model_free(g_model);
            g_model = nullptr;
        }
        
        llama_backend_free();
        
        model_loaded = false;
        current_model_path.clear();
    }
    
    // Check if model is loaded
    int32_t llama_is_loaded() {
        return (model_loaded && g_model && g_context) ? 1 : 0;
    }
}