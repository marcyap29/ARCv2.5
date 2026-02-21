#pragma once
#include <llama.h>
#include <string>
#include <vector>
#include <stdexcept>
#include <memory>
#include <algorithm>
#include <cmath>
#include <cstdlib>

// Simplified compatibility layer for llama.cpp API differences
// This version focuses on the core functionality needed for generation

#ifndef LLAMA_COMPAT_ASSERT
#define LLAMA_COMPAT_ASSERT(x) do { if(!(x)) throw std::runtime_error("llama compat assert: " #x); } while(0)
#endif

// Simple vocab access - try model first, then context
inline int compat_vocab_n_tokens(const llama_model *model, const llama_context *ctx) {
    if (model) {
        const llama_vocab* vocab = llama_model_get_vocab(model);
        if (vocab) {
            return llama_vocab_n_tokens(vocab);
        }
    }
    // Fallback: try to get from context if available
    if (ctx) {
        // Try different API variations
        #ifdef llama_n_vocab
        return llama_n_vocab(ctx);
        #else
        // If llama_n_vocab doesn't exist, return a reasonable default
        // We can't easily determine vocab size from logits without knowing the size
        return 32000; // Common vocab size for many models
        #endif
    }
    return 32000; // Default fallback
}

// Simple token to piece conversion
inline std::string compat_token_to_piece(const llama_model *model,
                                         const llama_context *ctx,
                                         llama_token tok) {
    if (model) {
        const llama_vocab* vocab = llama_model_get_vocab(model);
        if (vocab) {
            char piece[256];
            int n = llama_token_to_piece(vocab, tok, piece, sizeof(piece), 0, true);
            if (n > 0) {
                return std::string(piece, n);
            }
        }
    }
    // Fallback: try context-based API if available
    if (ctx) {
        #ifdef llama_token_to_str
        const char *p = llama_token_to_str(ctx, tok);
        return p ? std::string(p) : std::string();
        #else
        // If llama_token_to_str doesn't exist, return a placeholder
        return std::string("?");
        #endif
    }
    return std::string();
}

// Simple tokenization
inline std::vector<llama_token> compat_tokenize(const llama_model *model,
                                                const llama_context *ctx,
                                                const std::string &text,
                                                bool add_bos,
                                                bool parse_special = false) {
    std::vector<llama_token> out;
    
    if (model) {
        const llama_vocab* vocab = llama_model_get_vocab(model);
        if (vocab) {
            out.resize(text.size() + 8);
            int n = llama_tokenize(vocab, text.c_str(), (int)text.size(),
                                   out.data(), (int)out.size(),
                                   add_bos ? 1 : 0, parse_special ? 1 : 0);
            if (n < 0) { 
                out.resize((size_t)(-n));
                n = llama_tokenize(vocab, text.c_str(), (int)text.size(),
                                   out.data(), (int)out.size(),
                                   add_bos ? 1 : 0, parse_special ? 1 : 0);
            }
            out.resize((size_t)n);
            return out;
        }
    }
    
    // Fallback: try context-based API if available
    if (ctx) {
        out.resize(text.size() + 8);
        #ifdef llama_tokenize
        int n = llama_tokenize(ctx, text.c_str(), (int)text.size(),
                               out.data(), (int)out.size(), add_bos ? 1 : 0);
        if (n < 0) { 
            out.resize((size_t)(-n));
            n = llama_tokenize(ctx, text.c_str(), (int)text.size(),
                               out.data(), (int)out.size(), add_bos ? 1 : 0);
        }
        out.resize((size_t)n);
        #else
        // If llama_tokenize doesn't exist, return empty vector
        out.clear();
        #endif
    }
    
    return out;
}

// Simple special token discovery
struct compat_special_tokens {
    llama_token bos = -1;
    llama_token eos = -1;
    llama_token eot = -1;
};

inline compat_special_tokens compat_discover_specials(const llama_model *model,
                                                      const llama_context *ctx) {
    compat_special_tokens s;
    
    if (model) {
        const llama_vocab* vocab = llama_model_get_vocab(model);
        if (vocab) {
            s.bos = llama_vocab_bos(vocab);
            s.eos = llama_vocab_eos(vocab);
        }
    }
    
    // Fallback: try context-based API if available
    if (s.bos == -1 && ctx) {
        #ifdef llama_token_bos
        s.bos = llama_token_bos(ctx);
        #else
        s.bos = 1; // Common BOS token ID
        #endif
    }
    if (s.eos == -1 && ctx) {
        #ifdef llama_token_eos
        s.eos = llama_token_eos(ctx);
        #else
        s.eos = 2; // Common EOS token ID
        #endif
    }
    
    // Try to find EOT token
    std::vector<llama_token> t = compat_tokenize(model, ctx, "<|eot_id|>", false, true);
    if (!t.empty()) s.eot = t[0];
    if (s.eot < 0) {
        s.eot = s.eos; // fallback to EOS
    }
    
    return s;
}

// Simple sampler for fallback
struct compat_sampler {
    float temp = 0.8f;
    int32_t top_k = 40;
    float top_p = 0.95f;
    float min_p = 0.05f;
};

inline compat_sampler *compat_sampler_create(float temp, int32_t top_k, float top_p, float min_p) {
    auto *s = new compat_sampler();
    s->temp = temp; 
    s->top_k = top_k; 
    s->top_p = top_p; 
    s->min_p = min_p;
    return s;
}

inline void compat_sampler_free(compat_sampler *s) {
    delete s;
}

inline llama_token compat_sample_next(const llama_model *model,
                                      llama_context *ctx,
                                      compat_sampler *s) {
    const int n_vocab = compat_vocab_n_tokens(model, ctx);
    
    // Try to get logits, with fallback
    const float *logits = nullptr;
    #ifdef llama_get_logits
    logits = llama_get_logits(ctx);
    #endif
    
    if (!logits) {
        // Fallback: return a simple token
        return 1; // Common BOS token as fallback
    }
    
    // Simple greedy sampling for now
    llama_token best_token = 0;
    float best_logit = -1e9f;
    
    for (int i = 0; i < n_vocab; ++i) {
        if (logits[i] > best_logit) {
            best_logit = logits[i];
            best_token = i;
        }
    }
    
    return best_token;
}
