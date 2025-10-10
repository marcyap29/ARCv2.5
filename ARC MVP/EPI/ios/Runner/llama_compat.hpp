#pragma once
#include "../../third_party/llama.cpp/include/llama.h"
#include <string>
#include <vector>
#include <stdexcept>
#include <memory>
#include <algorithm>
#include <cmath>
#include <cstdlib>

// ---- Build/feature detection ------------------------------------------------
// llama.cpp typically exposes LLAMA_BUILD_NUMBER and friends via ggml/llama.h.
// We also feature-detect by checking for functions via macros the project sets.

#ifndef LLAMA_COMPAT_ASSERT
#define LLAMA_COMPAT_ASSERT(x) do { if(!(x)) throw std::runtime_error("llama compat assert: " #x); } while(0)
#endif

// Vocab access — older: llama_n_vocab(ctx) ; newer: llama_vocab_n_tokens(model)
inline int compat_vocab_n_tokens(const llama_model *model, const llama_context *ctx) {
    // Try newer API first
    if (model) {
        const llama_vocab* vocab = llama_model_get_vocab(model);
        if (vocab) {
            return llama_vocab_n_tokens(vocab);
        }
    }
    // Fallback to context-based API
    if (ctx) {
        return llama_n_vocab(ctx);
    }
    return 0;
}

// Token -> piece/text — signature drifted across versions
inline std::string compat_token_to_piece(const llama_model *model,
                                         const llama_context *ctx,
                                         llama_token tok) {
    // Try newer API first
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
    // Fallback to context-based API
    if (ctx) {
        const char *p = llama_token_to_str(ctx, tok);
        return p ? std::string(p) : std::string();
    }
    return std::string();
}

// Tokenize — older: llama_tokenize(ctx, …) ; newer: llama_tokenize(model, …)
// also: newer versions need "special tokens" flag.
inline std::vector<llama_token> compat_tokenize(const llama_model *model,
                                                const llama_context *ctx,
                                                const std::string &text,
                                                bool add_bos,
                                                bool parse_special = false) {
    std::vector<llama_token> out;
    
    // Try newer API first
    if (model) {
        const llama_vocab* vocab = llama_model_get_vocab(model);
        if (vocab) {
            out.resize(text.size() + 8); // roomy
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
    
    // Fallback to context-based API
    if (ctx) {
        out.resize(text.size() + 8);
        int n = llama_tokenize(ctx, text.c_str(), (int)text.size(),
                               out.data(), (int)out.size(), add_bos ? 1 : 0);
        if (n < 0) { 
            out.resize((size_t)(-n));
            n = llama_tokenize(ctx, text.c_str(), (int)text.size(),
                               out.data(), (int)out.size(), add_bos ? 1 : 0);
        }
        out.resize((size_t)n);
    }
    
    return out;
}

// BOS/EOS/EOT discovery (runtime)
struct compat_special_tokens {
    llama_token bos = -1;
    llama_token eos = -1;
    llama_token eot = -1; // end-of-turn for chat models
};

inline compat_special_tokens compat_discover_specials(const llama_model *model,
                                                      const llama_context *ctx) {
    compat_special_tokens s;
    
    // Try to get BOS/EOS from model
    if (model) {
        const llama_vocab* vocab = llama_model_get_vocab(model);
        if (vocab) {
            s.bos = llama_vocab_bos(vocab);
            s.eos = llama_vocab_eos(vocab);
        }
    }
    
    // Fallback to context-based API
    if (s.bos == -1 && ctx) {
        s.bos = llama_token_bos(ctx);
    }
    if (s.eos == -1 && ctx) {
        s.eos = llama_token_eos(ctx);
    }
    
    // Try common EOT ids; fall back to text probe
    // Many Llama 3.* builds use <|eot_id|> internally
    {
        // Probe via explicit piece if supported
        std::vector<llama_token> t = compat_tokenize(model, ctx, "<|eot_id|>", false, /*parse_special=*/true);
        if (!t.empty()) s.eot = t[0];
        if (s.eot < 0) {
            // fallback heuristic: if eos exists, reuse as stop
            s.eot = s.eos;
        }
    }
    return s;
}

// Sampler chain — present in newer llama.cpp; fall back to manual top-p/top-k.
struct compat_sampler {
#if defined(LLAMA_API_VERSION) || defined(LLAMA_BUILD_NUMBER)
    llama_sampler *chain = nullptr;
#endif
    float temp = 0.8f;
    int32_t top_k = 40;
    float top_p = 0.95f;
    float min_p = 0.05f;
};

inline compat_sampler *compat_sampler_create(float temp, int32_t top_k, float top_p, float min_p) {
    auto *s = new compat_sampler();
    s->temp = temp; s->top_k = top_k; s->top_p = top_p; s->min_p = min_p;
#if defined(LLAMA_API_VERSION) || defined(LLAMA_BUILD_NUMBER)
    llama_sampler_chain_params params = llama_sampler_chain_default_params();
    s->chain = llama_sampler_chain_init(params);
    llama_sampler_chain_add(s->chain, llama_sampler_init_top_k(top_k));
    llama_sampler_chain_add(s->chain, llama_sampler_init_min_p(min_p));
    llama_sampler_chain_add(s->chain, llama_sampler_init_tail_free(1.0f)); // mild
    llama_sampler_chain_add(s->chain, llama_sampler_init_typical(1.0f));
    llama_sampler_chain_add(s->chain, llama_sampler_init_top_p(top_p));
    llama_sampler_chain_add(s->chain, llama_sampler_init_temp(temp));
#endif
    return s;
}

inline void compat_sampler_free(compat_sampler *s) {
#if defined(LLAMA_API_VERSION) || defined(LLAMA_BUILD_NUMBER)
    if (s->chain) llama_sampler_free(s->chain);
#endif
    delete s;
}

inline llama_token compat_sample_next(const llama_model *model,
                                      llama_context *ctx,
                                      compat_sampler *s) {
#if defined(LLAMA_API_VERSION) || defined(LLAMA_BUILD_NUMBER)
    (void)model;
    const llama_token id = llama_sampler_sample(s->chain, ctx, -1 /*last tok*/);
    llama_sampler_accept(s->chain, id);
    return id;
#else
    (void)model;
    const int n_vocab = compat_vocab_n_tokens(model, ctx);
    std::vector<float> logits(n_vocab);
    const float *logits_ptr = llama_get_logits(ctx);
    for (int i = 0; i < n_vocab; ++i) logits[i] = logits_ptr[i];

    // Minimal top-k/top-p/temperature sampler (greedy-ish but safe)
    struct TokProb { int id; float p; };
    std::vector<TokProb> probs;
    probs.reserve(n_vocab);
    float maxlog = -1e30f;
    for (int i = 0; i < n_vocab; ++i) if (logits[i] > maxlog) maxlog = logits[i];
    double sum = 0.0;
    for (int i = 0; i < n_vocab; ++i) {
        float l = (logits[i] - maxlog) / std::max(s->temp, 1e-3f);
        float e = std::exp(l);
        sum += e;
        probs.push_back({i, (float)e});
    }
    for (auto &tp : probs) tp.p = (float)(tp.p / sum);
    std::sort(probs.begin(), probs.end(), [](auto &a, auto &b){ return a.p > b.p; });
    if (s->top_k > 0 && (int)probs.size() > s->top_k) probs.resize((size_t)s->top_k);
    // Nucleus
    float csum = 0.f; size_t cut = probs.size();
    for (size_t i = 0; i < probs.size(); ++i) { csum += probs[i].p; if (csum >= s->top_p) { cut = i+1; break; } }
    probs.resize(cut);
    // Sample by cumulative probability
    float r = (float)rand() / (float)RAND_MAX;
    csum = 0.f;
    for (auto &tp : probs) { csum += tp.p; if (r <= csum) return (llama_token)tp.id; }
    return (llama_token)probs.front().id;
#endif
}
