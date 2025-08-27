import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ffi/llama_bindings.dart';
import '../ffi/llama_types.dart';
import '../models/llm_model.dart';

class LlmService {
  static final LlmService _instance = LlmService._internal();
  factory LlmService() => _instance;
  
  late final LlamaBindings _bindings;
  int? _currentModelId;
  Pointer<LlamaDartContext>? _currentContext;
  int _contextLength = 2048;
  final Map<String, StreamController<String>> _generationControllers = {};
  
  LlmService._internal();
  
  Future<void> init() async {
    _bindings = LlamaBindings();
    
    final prefs = await SharedPreferences.getInstance();
    _contextLength = prefs.getInt('context_length') ?? 2048;
  }
  
  void setContextLength(int length) {
    _contextLength = length;
  }
  
  Future<bool> loadModel(LlmModel model) async {
    // Перевіримо, чи потрібно розвантажувати поточну модель
    if (_currentModelId != null && _currentContext != null) {
      _bindings.freeContext(_currentContext!);
      _currentContext = null;
    }
    
    final modelsDir = await _getModelsDirectory();
    final modelPath = '${modelsDir.path}/${model.id}.bin';
    
    try {
      // Завантажуємо модель з FFI інтерфейсу
      final quantType = model.quantization == QuantizationType.bit4 ? 4 : 8;
      
      _currentModelId = _bindings.loadModel(
        modelPath,
        quantizationType: quantType,
        nThreads: 4, // Можна зробити налаштованим
      );
      
      if (_currentModelId! <= 0) {
        return false;
      }
      
      // Створюємо контекст для моделі
      _currentContext = _bindings.createContext(_currentModelId!);
      return _currentContext != null;
    } catch (e) {
      debugPrint('Помилка завантаження моделі: $e');
      return false;
    }
  }
  
  String _formatPrompt(String prompt) {
    // Застосовуємо ChatML формат для Qwen моделей
    return "<|im_start|>user\n$prompt<|im_end|>\n<|im_start|>assistant\n";
  }

  Future<String> generateResponse(String prompt, {int maxTokens = 256}) async {
    if (_currentModelId == null || _currentContext == null) {
      throw Exception('Модель не завантажена');
    }
    
    try {
      // Форматуємо та токенізуємо вхідний текст
      final formattedPrompt = _formatPrompt(prompt);
      final tokens = _bindings.tokenize(_currentContext!, formattedPrompt);
      
      // Генеруємо відповідь
      final result = _bindings.generate(
        _currentContext!,
        tokens,
        maxTokens: maxTokens,
        contextLength: _contextLength,
        temperature: 0.8,
        topP: 0.9,
      );
      
      // Звільняємо пам'ять токенів
      _bindings.freeTokenizedText(tokens);
      
      return result;
    } catch (e) {
      debugPrint('Помилка генерації відповіді: $e');
      return 'Помилка генерації відповіді: $e';
    }
  }
  
  // Потокова генерація відповіді для відображення у реальному часі
  Stream<String> generateResponseStream(String prompt, {int maxTokens = 256}) {
    final streamId = DateTime.now().millisecondsSinceEpoch.toString();
    final controller = StreamController<String>();
    _generationControllers[streamId] = controller;
    
    Future<void> generate() async {
      if (_currentModelId == null || _currentContext == null) {
        controller.addError('Модель не завантажена');
        await controller.close();
        _generationControllers.remove(streamId);
        return;
      }
      
      try {
        // Поки що використовуємо синхронну генерацію та емулюємо потокову
        String result = await generateResponse(prompt, maxTokens: maxTokens);
        
        // Емулюємо потокову генерацію
        String accumulated = '';
        for (int i = 0; i < result.length; i++) {
          if (controller.isClosed) break;
          accumulated += result[i];
          controller.add(accumulated);
          await Future.delayed(const Duration(milliseconds: 20));
        }
        
        await controller.close();
      } catch (e) {
        controller.addError('Помилка генерації: $e');
        await controller.close();
      } finally {
        _generationControllers.remove(streamId);
      }
    }
    
    generate();
    return controller.stream;
  }
  
  void stopGeneration(String streamId) {
    final controller = _generationControllers[streamId];
    if (controller != null && !controller.isClosed) {
      controller.close();
      _generationControllers.remove(streamId);
    }
  }
  
  void unloadCurrentModel() {
    if (_currentContext != null) {
      _bindings.freeContext(_currentContext!);
      _currentContext = null;
      _currentModelId = null;
    }
  }
  
  Future<Directory> _getModelsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${appDir.path}/models');
    
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    
    return modelsDir;
  }
  
  // Мок-метод для тестування без реальної моделі
  Future<String> generateMockResponse(String prompt) async {
    await Future.delayed(const Duration(seconds: 2));
    return "Це тестова відповідь для запиту: $prompt. "
           "У реальній версії, тут буде відповідь від LLM моделі.";
  }
}