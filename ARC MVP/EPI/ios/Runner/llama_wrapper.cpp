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
            // For now, return a simple response to test the integration
            std::string response = "This is a test response from the llama.cpp model. The prompt was: " + std::string(prompt);
            
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
            
            // For now, just simulate streaming with a simple response
            current_response = "This is a streaming test response from llama.cpp. ";
            
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
            // Simulate streaming by returning words one by one
            static size_t word_index = 0;
            static std::vector<std::string> words = {"This", " ", "is", " ", "a", " ", "streaming", " ", "test", " ", "response", " ", "from", " ", "llama.cpp", "."};
            
            if (word_index < words.size()) {
                std::string word = words[word_index];
                word_index++;
                
                // Return a copy that won't be deallocated
                static char* token_cstr = nullptr;
                if (token_cstr) {
                    free(token_cstr);
                }
                token_cstr = (char*)malloc(word.length() + 1);
                strcpy(token_cstr, word.c_str());
                
                result.token = token_cstr;
                
                if (word_index >= words.size()) {
                    stream_finished = true;
                    generation_active = false;
                    result.is_finished = true;
                }
            } else {
                stream_finished = true;
                generation_active = false;
                result.is_finished = true;
            }
            
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