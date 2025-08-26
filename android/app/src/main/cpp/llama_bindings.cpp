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
    try {
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

        // Add a space in front of the prompt as per llama.cpp recommendation
        std::string text_str = " " + std::string(text);
        
        // Max tokens can be the length of the text + some buffer
        int n_max_tokens = text_str.length() + 256;
        std::vector<llama_token> tokens(n_max_tokens);

        // Tokenize
        int n_tokens = llama_tokenize(llama_ctx, text_str.c_str(), tokens.data(), n_max_tokens, true);

        if (n_tokens < 0) {
            LOGE("Failed to tokenize text. Result was %d", n_tokens);
            llama_dart_tokens* result = new llama_dart_tokens();
            result->nTokens = 0;
            result->tokens = nullptr;
            return result;
        }

        // Create result struct
        llama_dart_tokens* result = new llama_dart_tokens();
        result->nTokens = n_tokens;
        result->tokens = new int32_t[n_tokens];
        
        // Copy tokens
        std::copy(tokens.begin(), tokens.begin() + n_tokens, result->tokens);

        LOGI("Tokenized text into %d tokens", n_tokens);
        return result;

    } catch (const std::exception& e) {
        LOGE("Exception in llama_dart_tokenize: %s", e.what());
        return nullptr;
    }
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

        if (tokens->nTokens == 0) {
            char* output = new char[1];
            output[0] = '\0';
            return output;
        }

        int n_threads = 4;

        if (llama_eval(llama_ctx, tokens->tokens, tokens->nTokens, 0, n_threads)) {
            LOGE("Failed to eval prompt");
            const char* err_msg = "Failed to evaluate prompt.";
            char* output = new char[strlen(err_msg) + 1];
            strcpy(output, err_msg);
            return output;
        }

        std::string result_text;
        llama_token new_token_id = 0;
        int n_past = tokens->nTokens;
        const int max_new_tokens = params->maxTokens;
        
        const auto eos_token_id = llama_token_eos();
        const auto n_vocab = llama_n_vocab(llama_ctx);

        for (int i = 0; i < max_new_tokens; i++) {
            auto logits = llama_get_logits(llama_ctx);

            new_token_id = 0;
            float max_p = -1.0f;
            for (int j = 0; j < n_vocab; j++) {
                if (logits[j] > max_p) {
                    max_p = logits[j];
                    new_token_id = j;
                }
            }

            if (new_token_id == eos_token_id) {
                break;
            }

            const char* token_str = llama_token_get_text(llama_ctx, new_token_id);
            if (token_str) {
                result_text += token_str;
            }

            if (llama_eval(llama_ctx, &new_token_id, 1, n_past, n_threads)) {
                LOGE("Failed to eval new token");
                break;
            }
            n_past += 1;
        }

        char* output = new char[result_text.length() + 1];
        std::strcpy(output, result_text.c_str());

        LOGI("Generated text of length %zu", result_text.length());
        return output;

    } catch (const std::exception& e) {
        LOGE("Exception in llama_dart_generate: %s", e.what());
        const char* err_msg = e.what();
        char* output = new char[strlen(err_msg) + 1];
        strcpy(output, err_msg);
        return output;
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