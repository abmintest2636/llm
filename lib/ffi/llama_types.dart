import 'dart:ffi';
import 'package:ffi/ffi.dart';

// Структура для контексту (відповідає llama_dart_context в C++)
final class LlamaDartContext extends Struct {
  @Int64()
  external int handle;
}

// Структура для параметрів інференсу (відповідає llama_dart_inference_params в C++)
final class LlamaDartInferenceParams extends Struct {
  @Int32()
  external int maxTokens;
  
  @Int32()
  external int contextLength;
  
  @Float()
  external double temperature;
  
  @Float()
  external double topP;
  
  @Int32()
  external int seed;

  @Double()
  external double frequencyPenalty;
  
  @Double()
  external double presencePenalty;
}

// Структура для токенізованого тексту (відповідає llama_dart_tokens в C++)
final class LlamaDartTokens extends Struct {
  external Pointer<Int32> tokens;
  
  @Int32()
  external int nTokens;
}

// Параметри для завантаження моделі (відповідає llama_dart_model_params в C++)
final class LlamaDartModelParams extends Struct {
  @Int32()
  external int nGpuLayers;
  
  @Int32()
  external int quantizationType;
  
  @Int32()
  external int seed;
  
  @Int32()
  external int nThreads;
  
  @Int32()
  external int nBatch;
}

// Колбек для звітування про генерацію тексту
typedef LlamaProgressCallbackNative = Void Function(Int32 tokenId, Pointer<Utf8> piece);
typedef LlamaProgressCallback = void Function(int tokenId, Pointer<Utf8> piece);