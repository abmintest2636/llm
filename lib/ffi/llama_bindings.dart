import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'llama_types.dart';

class LlamaBindings {
  static final LlamaBindings _instance = LlamaBindings._internal();
  factory LlamaBindings() => _instance;
  
  late DynamicLibrary _lib;
  
  // FFI функції з правильними типами
  late final int Function(Pointer<Utf8>, Pointer<LlamaModelParams>) _loadModelFn;
  late final Pointer<LlamaContextStruct> Function(int) _createContextFn;
  late final Pointer<LlamaTokenizedText> Function(Pointer<LlamaContextStruct>, Pointer<Utf8>) _tokenizeFn;
  late final Pointer<Utf8> Function(Pointer<LlamaContextStruct>, Pointer<LlamaTokenizedText>, Pointer<LlamaInferenceParams>) _generateFn;
  late final void Function(Pointer<LlamaContextStruct>) _freeContextFn;
  late final void Function(Pointer<LlamaTokenizedText>) _freeTokensFn;
  late final void Function(Pointer<Utf8>) _freeStringFn;
  
  LlamaBindings._internal() {
    _loadLib();
    _initBindings();
  }
  
  void _loadLib() {
    if (Platform.isAndroid) {
      try {
        _lib = DynamicLibrary.open('libllama_bindings.so');
      } catch (e) {
        throw Exception('Не вдалось завантажити нативну бібліотеку: $e');
      }
    } else {
      throw UnsupportedError('Підтримується лише Android платформа');
    }
  }
  
  void _initBindings() {
    try {
      _loadModelFn = _lib.lookupFunction<
        Int32 Function(Pointer<Utf8>, Pointer<LlamaModelParams>),
        int Function(Pointer<Utf8>, Pointer<LlamaModelParams>)
      >('llama_load_model');
      
      _createContextFn = _lib.lookupFunction<
        Pointer<LlamaContextStruct> Function(Int32),
        Pointer<LlamaContextStruct> Function(int)
      >('llama_create_context');
      
      _tokenizeFn = _lib.lookupFunction<
        Pointer<LlamaTokenizedText> Function(Pointer<LlamaContextStruct>, Pointer<Utf8>),
        Pointer<LlamaTokenizedText> Function(Pointer<LlamaContextStruct>, Pointer<Utf8>)
      >('llama_tokenize');
      
      _generateFn = _lib.lookupFunction<
        Pointer<Utf8> Function(Pointer<LlamaContextStruct>, Pointer<LlamaTokenizedText>, Pointer<LlamaInferenceParams>),
        Pointer<Utf8> Function(Pointer<LlamaContextStruct>, Pointer<LlamaTokenizedText>, Pointer<LlamaInferenceParams>)
      >('llama_generate');
      
      _freeContextFn = _lib.lookupFunction<
        Void Function(Pointer<LlamaContextStruct>),
        void Function(Pointer<LlamaContextStruct>)
      >('llama_free_context');
      
      _freeTokensFn = _lib.lookupFunction<
        Void Function(Pointer<LlamaTokenizedText>),
        void Function(Pointer<LlamaTokenizedText>)
      >('llama_free_tokens');
      
      _freeStringFn = _lib.lookupFunction<
        Void Function(Pointer<Utf8>),
        void Function(Pointer<Utf8>)
      >('llama_free_string');
    } catch (e) {
      throw Exception('Не вдалось ініціалізувати FFI функції: $e');
    }
  }
  
  int loadModel(String path, {
    int quantizationType = 4,
    int nGpuLayers = 0,
    int seed = 0,
    int nThreads = 4,
    int nBatch = 512,
  }) {
    final pathPtr = path.toNativeUtf8();
    final params = calloc<LlamaModelParams>();
    
    params.ref.quantizationType = quantizationType;
    params.ref.nGpuLayers = nGpuLayers;
    params.ref.seed = seed;
    params.ref.nThreads = nThreads;
    params.ref.nBatch = nBatch;
    
    try {
      return _loadModelFn(pathPtr, params);
    } catch (e) {
      throw Exception('Помилка завантаження моделі: $e');
    } finally {
      calloc.free(pathPtr);
      calloc.free(params);
    }
  }
  
  Pointer<LlamaContextStruct> createContext(int modelId) {
    try {
      return _createContextFn(modelId);
    } catch (e) {
      throw Exception('Помилка створення контексту: $e');
    }
  }
  
  Pointer<LlamaTokenizedText> tokenize(Pointer<LlamaContextStruct> context, String text) {
    final textPtr = text.toNativeUtf8();
    try {
      return _tokenizeFn(context, textPtr);
    } catch (e) {
      throw Exception('Помилка токенізації: $e');
    } finally {
      calloc.free(textPtr);
    }
  }
  
  String generate(
    Pointer<LlamaContextStruct> context,
    Pointer<LlamaTokenizedText> tokens, {
    int maxTokens = 256,
    int contextLength = 2048,
    double temperature = 0.8,
    double topP = 0.9,
    int seed = 0,
    double frequencyPenalty = 0.0,
    double presencePenalty = 0.0,
  }) {
    final params = calloc<LlamaInferenceParams>();
    
    params.ref.maxTokens = maxTokens;
    params.ref.contextLength = contextLength;
    params.ref.temperature = temperature;
    params.ref.topP = topP;
    params.ref.seed = seed;
    params.ref.frequencyPenalty = frequencyPenalty;
    params.ref.presencePenalty = presencePenalty;
    
    try {
      final resultPtr = _generateFn(context, tokens, params);
      final result = resultPtr.toDartString();
      _freeStringFn(resultPtr);
      return result;
    } catch (e) {
      throw Exception('Помилка генерації тексту: $e');
    } finally {
      calloc.free(params);
    }
  }
  
  void freeContext(Pointer<LlamaContextStruct> context) {
    try {
      _freeContextFn(context);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Попередження: не вдалось звільнити контекст: $e');
      }
    }
  }
  
  void freeTokenizedText(Pointer<LlamaTokenizedText> tokens) {
    try {
      _freeTokensFn(tokens);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Попередження: не вдалось звільнити токени: $e');
      }
    }
  }
}