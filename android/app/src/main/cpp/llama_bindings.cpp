#include "llama_bindings.h"
#include "llama.h"
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
        
        // Конвертація параметрів для сучасної версії
        llama_model_params model_params = llama_model_default_params();
        model_params.n_gpu_layers = params->nGpuLayers;
        model_params.use_mlock = false;  // Для Android
        model_params.use_mmap = true;
        
        // Завантаження моделі з новим API
        llama_model* model = llama_model_load_from_file(path, model_params);
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
        
        llama_context* ctx = llama_init_from_model(it->second, ctx_params);
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
        const llama_model* model = llama_get_model(llama_ctx);
        const llama_vocab* vocab = llama_model_get_vocab(model);
        
        size_t text_len = strlen(text);
        
        // Створюємо буфер для токенів (оцінюємо максимальну кількість)
        int max_tokens = text_len * 2 + 256;
        std::vector<llama_token> tokens(max_tokens);
        
        // Викликаємо справжню токенізацію
        int n_tokens = llama_tokenize(vocab, text, text_len, tokens.data(), max_tokens, true, false);
        
        if (n_tokens < 0) {
            LOGE("Tokenization failed or buffer too small, needed: %d", -n_tokens);
            // Якщо буфер занадто малий, спробуємо ще раз з більшим буфером
            if (-n_tokens > max_tokens) {
                max_tokens = -n_tokens;
                tokens.resize(max_tokens);
                n_tokens = llama_tokenize(vocab, text, text_len, tokens.data(), max_tokens, true, false);
            }
        }
        
        if (n_tokens <= 0) {
            LOGE("Failed to tokenize text, falling back to single token");
            n_tokens = 1;
            tokens[0] = llama_vocab_bos(vocab); // Використовуємо BOS токен як заглушку
        }
        
        // Створення результату
        llama_dart_tokens* result = new llama_dart_tokens();
        result->nTokens = n_tokens;
        result->tokens = new int32_t[n_tokens];
        
        // Копіюємо токени
        for (int i = 0; i < n_tokens; i++) {
            result->tokens[i] = tokens[i];
        }
        
        LOGI("Tokenized text '%s' into %d tokens", text, n_tokens);
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
        const llama_model* model = llama_get_model(llama_ctx);
        const llama_vocab* vocab = llama_model_get_vocab(model);

        std::string result_text;

        // Очищуємо KV кеш перед новою генерацією, щоб уникнути "протікання" контексту
        llama_kv_cache_clear(llama_ctx);

        // 1. Обробка вхідного промпту
        std::vector<llama_token> input_tokens;
        for (int i = 0; i < tokens->nTokens; i++) {
            input_tokens.push_back(tokens->tokens[i]);
        }
        
        int n_past = 0;
        int n_batch = llama_context_get_n_batch(llama_ctx);

        for (int i = 0; i < input_tokens.size(); i += n_batch) {
            int n_eval = (int)input_tokens.size() - i;
            if (n_eval > n_batch) {
                n_eval = n_batch;
            }
            if (llama_decode(llama_ctx, llama_batch_get_one(&input_tokens[i], n_eval, n_past, 0))) {
                LOGE("Failed to eval prompt tokens");
                result_text = "Error: Failed to process input tokens.";
                char* output = new char[result_text.length() + 1];
                std::strcpy(output, result_text.c_str());
                return output;
            }
            n_past += n_eval;
        }

        // 2. Цикл генерації нових токенів
        std::vector<llama_token> generated_tokens;
        int max_gen_tokens = std::min(params->maxTokens, (int)llama_context_get_n_ctx(llama_ctx) - n_past);

        for (int i = 0; i < max_gen_tokens; ++i) {
            // Отримуємо logits для останнього токена
            auto logits = llama_get_logits_ith(llama_ctx, n_past - 1);
            if (!logits) {
                 LOGE("Failed to get logits");
                 result_text = "Error: Failed to get model logits.";
                 break;
            }

            // Створюємо список кандидатів на токен
            std::vector<llama_token_data> candidates;
            candidates.reserve(llama_model_get_n_vocab(model));
            for (llama_token token_id = 0; token_id < llama_model_get_n_vocab(model); ++token_id) {
                candidates.push_back({token_id, logits[token_id], 0.0f});
            }
            llama_token_data_array candidates_p = { candidates.data(), candidates.size(), false };
            
            // Семплінг (простий top-k, top-p, temp)
            llama_sample_top_k(llama_ctx, &candidates_p, 40, 1);
            llama_sample_top_p(llama_ctx, &candidates_p, params->topP, 1);
            llama_sample_temp(llama_ctx, &candidates_p, params->temperature);
            llama_token new_token_id = llama_sample_token(llama_ctx, &candidates_p);

            // Перевірка на токен кінця послідовності (EOG)
            if (llama_vocab_is_eog(vocab, new_token_id)) {
                LOGI("EOG token found, stopping generation.");
                break;
            }

            generated_tokens.push_back(new_token_id);
            
            // Обробка нового токена для підтримки контексту
            if (llama_decode(llama_ctx, llama_batch_get_one(&new_token_id, 1, n_past, 0))) {
                LOGE("Failed to eval new token");
                break;
            }
            n_past++;
        }

        // 3. Конвертація згенерованих токенів у текст
        if (!generated_tokens.empty()) {
            std::vector<char> text_buffer(generated_tokens.size() * 10 + 256);
            int text_len = llama_detokenize(vocab, generated_tokens.data(), generated_tokens.size(),
                                          text_buffer.data(), text_buffer.size(), false, false);
            if (text_len > 0) {
                result_text = std::string(text_buffer.data(), text_len);
            } else {
                result_text = "Error: Failed to convert tokens to text.";
            }
        } else {
            // Перевірка, чи не було помилки раніше
            if (result_text.empty()) {
                result_text = "Error: No tokens generated.";
            }
        }

        char* output = new char[result_text.length() + 1];
        std::strcpy(output, result_text.c_str());

        LOGI("Generated text: %s", result_text.c_str());
        return output;

    } catch (const std::exception& e) {
        LOGE("Exception in llama_dart_generate: %s", e.what());
        // Повертаємо повідомлення про помилку, щоб Dart міг його обробити
        std::string error_msg = "Error: Exception in C++ generate.";
        char* output = new char[error_msg.length() + 1];
        std::strcpy(output, error_msg.c_str());
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