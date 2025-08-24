import 'dart:ffi';
import 'package:ffi/ffi.dart';

// Dart FFI type definitions matching llama_bindings.h

// Context handle
final class LlamaDartContext extends Struct {
  @Int64()
  external int handle;
}

// Inference parameters
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

// Tokenized text
final class LlamaDartTokens extends Struct {
  external Pointer<Int32> tokens;
  
  @Int32()
  external int nTokens;
}

// Model loading parameters
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

// Progress callback function types
typedef LlamaDartProgressCallbackNative = Void Function(Int32 tokenId, Pointer<Utf8> piece);
typedef LlamaDartProgressCallback = void Function(int tokenId, Pointer<Utf8> piece);