#include "llama_wrapper.h"
#include "llama.h"

#include <vector>
#include <string>
#include <mutex>
#include <cmath>
#include <algorithm>
#include <random>

static llama_model*   g_model = nullptr;
static llama_context* g_ctx   = nullptr;
static std::mutex     g_mu;
static bool           g_started = false;

// simple sampler knobs
static int32_t g_top_k = 40;
static float   g_top_p = 0.9f;
static float   g_temp  = 0.8f;

// random engine for sampling
static std::mt19937 rng{ std::random_device{}() };

static llama_token sample_from_logits(const float* logits, int32_t n_vocab) {
    // temperature
    std::vector<float> probs(n_vocab);
    float invT = (g_temp > 0.0f) ? (1.0f / g_temp) : 1.0f;

    float maxlog = logits[0];
    for (int i = 1; i < n_vocab; ++i) if (logits[i] > maxlog) maxlog = logits[i];

    double sum = 0.0;
    for (int i = 0; i < n_vocab; ++i) {
        double v = std::exp((logits[i] - maxlog) * invT);
        probs[i] = (float)v;
        sum += v;
    }
    for (int i = 0; i < n_vocab; ++i) probs[i] = (float)(probs[i] / sum);

    // top-k
    std::vector<int> idx(n_vocab);
    for (int i = 0; i < n_vocab; ++i) idx[i] = i;
    std::partial_sort(idx.begin(), idx.begin() + g_top_k, idx.end(),
        [&](int a, int b){ return probs[a] > probs[b]; });
    idx.resize(std::min<int>(g_top_k, n_vocab));

    // renormalize top-k
    double s2 = 0.0;
    for (int id : idx) s2 += probs[id];
    for (int id : idx) probs[id] = (float)(probs[id] / s2);

    // top-p cumulative cut
    std::sort(idx.begin(), idx.end(), [&](int a, int b){ return probs[a] > probs[b]; });
    double cum = 0.0;
    int cutoff = (int)idx.size();
    for (int i = 0; i < (int)idx.size(); ++i) {
        cum += probs[idx[i]];
        if (cum >= g_top_p) { cutoff = i + 1; break; }
    }
    idx.resize(cutoff);

    // categorical sample
    std::uniform_real_distribution<float> dist(0.0f, 1.0f);
    float r = dist(rng);
    float acc = 0.0f;
    for (int id : idx) {
        acc += probs[id];
        if (r <= acc) return (llama_token)id;
    }
    return (llama_token)idx.back();
}

bool epi_llama_init(const char* model_path, int32_t ctx_size_tokens, int32_t n_gpu_layers) {
    std::lock_guard<std::mutex> lk(g_mu);

    if (g_ctx || g_model) epi_llama_free();

    llama_model_params mparams = llama_model_default_params();
    // Offload control. Start with auto if 0, or set explicit layers
    if (n_gpu_layers > 0) mparams.n_gpu_layers = n_gpu_layers;

    g_model = llama_load_model_from_file(model_path, mparams);
    if (!g_model) return false;

    llama_context_params cparams = llama_context_default_params();
    cparams.n_ctx = ctx_size_tokens;

    g_ctx = llama_new_context_with_model(g_model, cparams);
    return g_ctx != nullptr;
}

void epi_llama_free(void) {
    std::lock_guard<std::mutex> lk(g_mu);
    if (g_ctx)   { llama_free(g_ctx);   g_ctx = nullptr; }
    if (g_model) { llama_free_model(g_model); g_model = nullptr; }
    g_started = false;
}

bool epi_llama_start(const char* prompt_utf8) {
    std::lock_guard<std::mutex> lk(g_mu);
    if (!g_ctx || !g_model) return false;

    const int add_bos = 1;
    // first estimate token count
    int needed = llama_tokenize(g_model, prompt_utf8, nullptr, 0, add_bos, true);
    if (needed <= 0) return false;

    std::vector<llama_token> toks(needed);
    int n = llama_tokenize(g_model, prompt_utf8, toks.data(), needed, add_bos, true);
    if (n <= 0) return false;

    llama_batch batch = llama_batch_init(n, 0, 1);
    for (int i = 0; i < n; ++i) {
        llama_batch_add(batch, toks[i], i, 0, false);
    }

    int rc = llama_decode(g_ctx, batch);
    llama_batch_free(batch);

    g_started = (rc == 0);
    return g_started;
}

bool epi_llama_generate_next(llama_token_callback_t on_token, void* user_data, bool* out_is_eos) {
    std::lock_guard<std::mutex> lk(g_mu);
    if (!g_ctx || !g_model || !g_started) return false;

    const float* logits = llama_get_logits(g_ctx);
    const int32_t n_vocab = llama_n_vocab(g_model);
    llama_token token = sample_from_logits(logits, n_vocab);

    char buf[512];
    int n = llama_token_to_piece(g_model, token, buf, sizeof(buf), true, false);
    if (n < 0) return false;
    if (on_token) on_token(buf, user_data);

    const int eos = llama_token_eos(g_model);
    if (token == eos) {
        if (out_is_eos) *out_is_eos = true;
        return true;
    }

    llama_batch step = llama_batch_init(1, 0, 1);
    llama_batch_add(step, token, 0, 0, true);
    int rc = llama_decode(g_ctx, step);
    llama_batch_free(step);

    if (out_is_eos) *out_is_eos = false;
    return rc == 0;
}

void epi_llama_stop(void) {
    std::lock_guard<std::mutex> lk(g_mu);
    g_started = false;
}

void epi_set_top_k(int32_t top_k) { if (top_k > 0) g_top_k = top_k; }
void epi_set_top_p(float top_p)   { if (top_p > 0.0f && top_p <= 1.0f) g_top_p = top_p; }
void epi_set_temp(float temperature) { if (temperature >= 0.0f) g_temp = temperature; }