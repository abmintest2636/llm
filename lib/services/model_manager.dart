import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/llm_model.dart';

class ModelManager extends ChangeNotifier {
  List<LlmModel> _models = [];
  String? _activeModelId;
  late SharedPreferences _prefs;
  
  List<LlmModel> get models => _models;
  
  LlmModel? get activeModel {
    if (_activeModelId == null) return null;
    try {
      return _models.firstWhere((m) => m.id == _activeModelId);
    } catch (_) {
      return null;
    }
  }
  
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _activeModelId = _prefs.getString('active_model_id');
    
    // Add pre-defined models
    _models = [
      LlmModel(
        id: 'gemma-3n-E2B-it-Q4_K_M',
        name: 'Gemma 3n E2B It (4-bit)',
        description: 'A 3rd generation, lightweight, state-of-the-art open model from Google.',
        url: 'https://huggingface.co/unsloth/gemma-3n-E2B-it-GGUF/resolve/main/gemma-3n-E2B-it-Q4_K_M.gguf?download=true',
        size: 3030000000, // ~3.03 GB
        quantization: QuantizationType.bit4,
      ),
      LlmModel(
        id: 'phi-3-mini-4k-instruct-q4',
        name: 'Phi-3 Mini Instruct (4-bit)',
        description: 'A 3.8B parameter, lightweight, state-of-the-art open model from Microsoft.',
        url: 'https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/Phi-3-mini-4k-instruct-q4.gguf?download=true',
        size: 2390000000, // ~2.39 GB
        quantization: QuantizationType.bit4,
      ),
    ];
    
    // Check which models are already downloaded
    await _checkDownloadedModels();
  }
  
  Future<void> _checkDownloadedModels() async {
    final modelsDir = await _getModelsDirectory();
    
    for (int i = 0; i < _models.length; i++) {
      final model = _models[i];
      final modelFile = File('${modelsDir.path}/${model.id}.bin');
      
      if (await modelFile.exists()) {
        _models[i] = model.copyWith(
          status: model.id == _activeModelId 
            ? ModelStatus.active 
            : ModelStatus.downloaded
        );
      }
    }
    
    notifyListeners();
  }
  
  Future<Directory> _getModelsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${appDir.path}/models');
    
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    
    return modelsDir;
  }
  
  Future<void> downloadModel(String modelId) async {
    final modelIndex = _models.indexWhere((m) => m.id == modelId);
    if (modelIndex == -1) return;
    
    final model = _models[modelIndex];
    final modelsDir = await _getModelsDirectory();
    final modelFile = File('${modelsDir.path}/${model.id}.bin');
    
    // Update model status to "downloading"
    _models[modelIndex] = model.copyWith(
      status: ModelStatus.downloading,
      downloadProgress: 0.0,
    );
    notifyListeners();
    
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(model.url));
      final response = await client.send(request);
      
      if (response.statusCode == 200) {
        final contentLength = response.contentLength ?? 0;
        final sink = modelFile.openWrite();
        int received = 0;
        
        final subscription = response.stream.listen(
          (chunk) {
            sink.add(chunk);
            received += chunk.length;
            
            if (contentLength > 0) {
              final progress = received / contentLength;
              _models[modelIndex] = model.copyWith(
                status: ModelStatus.downloading,
                downloadProgress: progress,
              );
              notifyListeners();
            }
          },
          onDone: () async {
            await sink.close();
            _models[modelIndex] = model.copyWith(
              status: ModelStatus.downloaded,
              downloadProgress: 1.0,
            );
            notifyListeners();
          },
          onError: (_) async {
            await sink.close();
            await modelFile.delete();
            _models[modelIndex] = model.copyWith(
              status: ModelStatus.error,
            );
            notifyListeners();
          },
          cancelOnError: true,
        );
        
        // Wait for the download to complete
        await subscription.asFuture();
      } else {
        _models[modelIndex] = model.copyWith(
          status: ModelStatus.error,
        );
        notifyListeners();
      }
    } catch (e) {
      _models[modelIndex] = model.copyWith(
        status: ModelStatus.error,
      );
      notifyListeners();
      rethrow;
    }
  }
  
  Future<void> deleteModel(String modelId) async {
    final modelIndex = _models.indexWhere((m) => m.id == modelId);
    if (modelIndex == -1) return;
    
    final model = _models[modelIndex];
    final modelsDir = await _getModelsDirectory();
    final modelFile = File('${modelsDir.path}/${model.id}.bin');
    
    if (await modelFile.exists()) {
      await modelFile.delete();
    }
    
    _models[modelIndex] = model.copyWith(
      status: ModelStatus.notDownloaded,
      downloadProgress: 0.0,
    );
    
    if (_activeModelId == modelId) {
      _activeModelId = null;
      await _prefs.remove('active_model_id');
    }
    
    notifyListeners();
  }
  
  Future<bool> setActiveModel(String modelId) async {
    if (_activeModelId == modelId) return true;
    
    final modelIndex = _models.indexWhere((m) => m.id == modelId);
    if (modelIndex == -1) return false;
    
    // Check if the model is downloaded
    if (_models[modelIndex].status != ModelStatus.downloaded) {
      return false;
    }
    
    // Update the previous active model
    if (_activeModelId != null) {
      final oldActiveIndex = _models.indexWhere((m) => m.id == _activeModelId);
      if (oldActiveIndex != -1) {
        _models[oldActiveIndex] = _models[oldActiveIndex].copyWith(
          status: ModelStatus.downloaded,
        );
      }
    }
    
    // Set the new active model
    _models[modelIndex] = _models[modelIndex].copyWith(
      status: ModelStatus.active,
    );
    
    _activeModelId = modelId;
    await _prefs.setString('active_model_id', modelId);
    
    notifyListeners();
    return true;
  }
  
  Future<void> updateModelQuantization(String modelId, QuantizationType quantization) async {
    final modelIndex = _models.indexWhere((m) => m.id == modelId);
    if (modelIndex == -1) return;
    
    _models[modelIndex] = _models[modelIndex].copyWith(
      quantization: quantization,
    );
    
    notifyListeners();
  }
}