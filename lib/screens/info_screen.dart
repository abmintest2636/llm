import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/llm_model.dart';
import '../services/model_manager.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.psychology,
                    size: 80,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Local LLM Chat',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Version 1.0.0',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'About the App',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Local LLM Chat is an application for communicating with large language models (LLMs) locally on your device, without sending data to the internet.',
                    ),
                    SizedBox(height: 8),
                    Text(
                      'The application uses optimized models that run entirely on your device, ensuring privacy and the ability to use it without an internet connection.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Available Models',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Consumer<ModelManager>(
                      builder: (context, modelManager, child) {
                        return Column(
                          children: modelManager.models.map((model) {
                            return ListTile(
                              leading: const Icon(Icons.model_training),
                              title: Text(model.name),
                              subtitle: Text(
                                model.description,
                                style: TextStyle(color: Colors.grey[400]),
                              ),
                              trailing: _getModelStatusIcon(model.status),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Technologies',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    ListTile(
                      leading: Icon(Icons.flutter_dash),
                      title: Text('Flutter'),
                      subtitle: Text('Framework for developing cross-platform applications'),
                    ),
                    ListTile(
                      leading: Icon(Icons.code),
                      title: Text('llama.cpp'),
                      subtitle: Text('Library for running LLM models on devices with limited resources'),
                    ),
                    ListTile(
                      leading: Icon(Icons.memory),
                      title: Text('Quantization'),
                      subtitle: Text('Technology for reducing model size while maintaining performance'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'License',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'This application is distributed under the MIT license. The models have their own separate licenses and terms of use.',
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Gemma - © 2024 Google, distributed under the Gemma Terms license.',
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Phi - © 2024 Microsoft, distributed under the Microsoft Phi License.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      );
  }
  
  Widget _getModelStatusIcon(ModelStatus status) {
    switch (status) {
      case ModelStatus.active:
        return const Icon(Icons.check_circle, color: Colors.green);
      case ModelStatus.downloaded:
        return const Icon(Icons.download_done, color: Colors.blue);
      case ModelStatus.downloading:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case ModelStatus.finalizing:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
        );
      case ModelStatus.notDownloaded:
        return const Icon(Icons.download, color: Colors.grey);
      case ModelStatus.error:
        return const Icon(Icons.error, color: Colors.red);
    }
  }
}