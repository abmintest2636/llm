#include "llama_bindings.h"
#include "llama.h"
#include "common.h"
#include <android/log.h>
#include <string>
#include <vector>
#include <map>
#include <memory>
#include <cstring>
#include <algorithm>

#define LOG_TAG "LlamaBindings"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// Глобальні змінні для керування моделями та контекстами
static std::map<int32_t, llama_model*> g_models;
static std::map<int64_t, llama_context*> g_contexts;
static int32_t g_next_model_id = 1;
static int64_t g_next_context_id = 1;
static llama_dart_progress_callback g_progress_callback = nullptr;

extern "C" {

int32_t llama_dart_load_model(const char* path, llama_dart_model_params* params) {
    try {
        LOGI("Loading model from: %s", path);
        
        // Ініціалізація backend
        llama_backend_init();
        
        // Конвертація параметрів для старої версії
        llama_model_params model_params = llama_model_default_params();
        model_params.n_gpu_layers = params->nGpuLayers;
        model_params.use_mlock = false;  // Для Android
        model_params.use_mmap = true;
        
        // Завантаження моделі
        llama_model* model = llama_load_model_from_file(path, model_params);
        if (!model) {
            LOGE("Failed to load model from: %s", path);
            return -1;
        }
        
        int32_t model_id = g_next_model_id++;
        g_models[model_id] = model;
        
        LOGI("Model loaded successfully with ID: %d", model_id);
        return model_id;
        
    } catch (const std::exception& e) {
        LOGE("Exception in llama_dart_load_model: %s", e.what());
        return -1;
    }
}

llama_dart_context* llama_dart_create_context(int32_t model_id) {
    try {
        auto it = g_models.find(model_id);
        if (it == g_models.end()) {
            LOGE("Model ID %d not found", model_id);
            return nullptr;
        }
        
        llama_context_params ctx_params = llama_context_default_params();
        ctx_params.n_ctx = 2048;  // Контекст
        ctx_params.n_batch = 512;
        ctx_params.n_threads = 4;
        
        llama_context* ctx = llama_new_context_with_model(it->second, ctx_params);
        if (!ctx) {
            LOGE("Failed to create context for model %d", model_id);
            return nullptr;
        }
        
        int64_t context_id = g_next_context_id++;
        g_contexts[context_id] = ctx;
        
        llama_dart_context* dart_ctx = new llama_dart_context();
        dart_ctx->handle = context_id;
        
        LOGI("Context created with ID: %ld", context_id);
        return dart_ctx;
        
    } catch (const std::exception& e) {
        LOGE("Exception in llama_dart_create_context: %s", e.what());
        return nullptr;
    }
}

llama_dart_tokens* llama_dart_tokenize(llama_dart_context* ctx, const char* text) {
    if (!ctx || !text) {
        LOGE("Invalid parameters for tokenization");
        return nullptr;
    }

    auto it = g_contexts.find(ctx->handle);
    if (it == g_contexts.end()) {
        LOGE("Context handle %ld not found", ctx->handle);
        return nullptr;
    }
    llama_context* llama_ctx = it->second;
    const llama_model* model = llama_get_model(llama_ctx);
    const llama_vocab* vocab = llama_model_get_vocab(model);

    // Prepare for tokenization
    const int n_ctx = llama_n_ctx(llama_ctx);
    std::vector<llama_token> tokens(n_ctx);
    bool add_special = llama_vocab_get_add_bos(vocab);

    // Tokenize the text
    int n_tokens = llama_tokenize(vocab, text, strlen(text), tokens.data(), n_ctx, add_special, false);

    if (n_tokens < 0) {
        LOGE("Failed to tokenize text.");
        return nullptr;
    }

    // Create and populate the result struct
    llama_dart_tokens* result = new llama_dart_tokens();
    result->nTokens = n_tokens;
    result->tokens = new int32_t[n_tokens];
    for (int i = 0; i < n_tokens; ++i) {
        result->tokens[i] = tokens[i];
    }

    LOGI("Tokenized text into %d tokens", n_tokens);
    return result;
}

char* llama_dart_generate(llama_dart_context* ctx, llama_dart_tokens* tokens, llama_dart_inference_params* params) {
    try {
        if (!ctx || !tokens || !params) {
            LOGE("Invalid parameters for generation");
            return nullptr;
        }
        
        auto it = g_contexts.find(ctx->handle);
        if (it == g_contexts.end()) {
            LOGE("Context handle %ld not found", ctx->handle);
            return nullptr;
        }

        llama_context* llama_ctx = it->second;
        const llama_model* model = llama_get_model(llama_ctx);
        const llama_vocab* vocab = llama_model_get_vocab(model);

        // Prepare input tokens
        std::vector<llama_token> input_tokens;
        for (int i = 0; i < tokens->nTokens; ++i) {
            input_tokens.push_back(tokens->tokens[i]);
        }

        llama_batch batch = llama_batch_init(input_tokens.size(), 0, 1);
        for (size_t i = 0; i < input_tokens.size(); ++i) {
            llama_batch_add(batch, input_tokens[i], i, { 0 }, true);
        }

        // Evaluate the initial prompt
        if (llama_decode(llama_ctx, batch) != 0) {
            LOGE("Failed to eval initial prompt");
            llama_batch_free(batch);
            return nullptr;
        }
        llama_batch_free(batch);

        // Main generation loop
        std::string result_text;
        const int max_new_tokens = params->maxTokens;
        llama_token eos_token = llama_vocab_eos(vocab);

        for (int i = 0; i < max_new_tokens; ++i) {
            float* logits = llama_get_logits_ith(llama_ctx, i);
            std::vector<llama_token_data> candidates;
            candidates.reserve(llama_vocab_n_tokens(vocab));
            for (llama_token token_id = 0; token_id < llama_vocab_n_tokens(vocab); ++token_id) {
                candidates.push_back({token_id, logits[token_id], 0.0f});
            }
            llama_token_data_array candidates_p = { candidates.data(), candidates.size(), false };

            llama_token new_token = llama_sample_token_greedy(llama_ctx, &candidates_p);

            if (new_token == eos_token) {
                break;
            }

            result_text += llama_token_to_piece(vocab, new_token);

            // Prepare the next batch
            batch = llama_batch_init(1, 0, 1);
            llama_batch_add(batch, new_token, input_tokens.size() + i, { 0 }, true);
            if (llama_decode(llama_ctx, batch) != 0) {
                LOGE("Failed to eval new token");
                llama_batch_free(batch);
                break;
            }
            llama_batch_free(batch);
        }

        // Copy result to a C-style string
        char* output = new char[result_text.length() + 1];
        std::strcpy(output, result_text.c_str());

        LOGI("Generated text of length: %zu", result_text.length());
        return output;

    } catch (const std::exception& e) {
        LOGE("Exception in llama_dart_generate: %s", e.what());
        return nullptr;
    }
}

void llama_dart_free_context(llama_dart_context* ctx) {
    if (ctx) {
        auto it = g_contexts.find(ctx->handle);
        if (it != g_contexts.end()) {
            llama_free(it->second);
            g_contexts.erase(it);
            LOGI("Context %ld freed", ctx->handle);
        }
        delete ctx;
    }
}

void llama_dart_free_tokens(llama_dart_tokens* tokens) {
    if (tokens) {
        if (tokens->tokens) {
            delete[] tokens->tokens;
        }
        delete tokens;
    }
}

void llama_dart_free_string(char* str) {
    if (str) {
        delete[] str;
    }
}

void llama_dart_set_progress_callback(llama_dart_progress_callback callback) {
    g_progress_callback = callback;
}

} // extern "C"