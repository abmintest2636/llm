import 'dart:ffi';
import 'package:ffi/ffi.dart';

// Структура для моделі
final class LlamaContextStruct extends Struct {
  @Int64()
  external int handle;
}

// Структура для параметрів інференсу
final class LlamaInferenceParams extends Struct {
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

// Структура для токенізованого тексту
final class LlamaTokenizedText extends Struct {
  external Pointer<Int32> tokens;
  
  @Int32()
  external int nTokens;
}

// Параметри для завантаження моделі
final class LlamaModelParams extends Struct {
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