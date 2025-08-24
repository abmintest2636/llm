import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/llm_model.dart';
import '../services/model_manager.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Про додаток'),
      ),
      body: SingleChildScrollView(
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
                    'Версія 1.0.0',
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
                      'Про додаток',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Local LLM Chat - це додаток для спілкування з великими мовними моделями (LLM) локально на вашому пристрої, без передачі даних в інтернет.',
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Додаток використовує оптимізовані моделі, які працюють повністю на вашому пристрої, забезпечуючи приватність та можливість використання без підключення до інтернету.',
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
                      'Доступні моделі',
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
                      'Технології',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    ListTile(
                      leading: Icon(Icons.flutter_dash),
                      title: Text('Flutter'),
                      subtitle: Text('Фреймворк для розробки кросплатформенних додатків'),
                    ),
                    ListTile(
                      leading: Icon(Icons.code),
                      title: Text('llama.cpp'),
                      subtitle: Text('Бібліотека для запуску LLM-моделей на пристроях з обмеженими ресурсами'),
                    ),
                    ListTile(
                      leading: Icon(Icons.memory),
                      title: Text('Quantization'),
                      subtitle: Text('Технологія для зменшення розміру моделей зі збереженням продуктивності'),
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
                      'Ліцензія',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Цей додаток розповсюджується під ліцензією MIT. Моделі мають свої окремі ліцензії та умови використання.',
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Gemma - © 2024 Google, розповсюджується під ліцензією Gemma Terms.',
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Phi - © 2024 Microsoft, розповсюджується під ліцензією Microsoft Phi License.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
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
      case ModelStatus.notDownloaded:
        return const Icon(Icons.download, color: Colors.grey);
      case ModelStatus.error:
        return const Icon(Icons.error, color: Colors.red);
    }
  }
}