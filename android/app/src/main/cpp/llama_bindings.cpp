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

// Global variables for managing models and contexts
static std::map<int32_t, llama_model*> g_models;
static std::map<int64_t, llama_context*> g_contexts;
static int32_t g_next_model_id = 1;
static int64_t g_next_context_id = 1;
static llama_dart_progress_callback g_progress_callback = nullptr;

extern "C" {

int32_t llama_dart_load_model(const char* path, llama_dart_model_params* params) {
    try {
        LOGI("Loading model from: %s", path);
        
        // Initialize backend
        llama_backend_init();
        
        // Convert parameters
        llama_model_params model_params = llama_model_default_params();
        model_params.n_gpu_layers = params->nGpuLayers;
        model_params.use_mlock = false;  // For Android
        model_params.use_mmap = true;
        
        // Load the model
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
        ctx_params.n_ctx = 2048;  // Context
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
    llama_model* model = llama_get_model(llama_ctx);

    // Prepare for tokenization
    const int n_ctx = llama_n_ctx(llama_ctx);
    std::vector<llama_token> tokens(n_ctx);
    bool add_bos = llama_should_add_bos_token(model);

    // Tokenize the text
    int n_tokens = llama_tokenize(model, text, strlen(text), tokens.data(), n_ctx, add_bos, false);

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
        llama_model* model = llama_get_model(llama_ctx);

        // Prepare input tokens
        std::vector<llama_token> input_tokens;
        for (int i = 0; i < tokens->nTokens; ++i) {
            input_tokens.push_back(tokens->tokens[i]);
        }

        // Evaluate the initial prompt
        if (llama_eval(llama_ctx, input_tokens.data(), input_tokens.size(), llama_get_kv_cache_token_count(llama_ctx)) != 0) {
            LOGE("Failed to eval initial prompt");
            return nullptr;
        }

        // Main generation loop
        std::string result_text;
        const int max_new_tokens = params->maxTokens;
        llama_token eos_token = llama_token_eos(model);

        for (int i = 0; i < max_new_tokens; ++i) {
            // Sample the next token
            llama_token_data_array candidates;
            candidates.data = new llama_token_data[llama_n_vocab(model)];
            candidates.size = llama_n_vocab(model);
            candidates.sorted = false;
            
            llama_get_logits_ith(llama_ctx, llama_get_kv_cache_token_count(llama_ctx) - 1, candidates.data);

            // Apply samplers
            llama_sample_top_p(llama_ctx, &candidates, params->topP, 1);
            llama_sample_temp(llama_ctx, &candidates, params->temperature);
            
            llama_token new_token = llama_sample_token(llama_ctx, &candidates);
            
            delete[] candidates.data;

            // Check for EOS token
            if (new_token == eos_token) {
                break;
            }

            // Convert token to string and append to result
            const char* piece = llama_token_to_piece(llama_ctx, new_token);
            result_text += piece;

            // Feed the new token back into the context
            llama_token eval_tokens[] = {new_token};
            if (llama_eval(llama_ctx, eval_tokens, 1, llama_get_kv_cache_token_count(llama_ctx)) != 0) {
                LOGE("Failed to eval new token");
                break;
            }
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