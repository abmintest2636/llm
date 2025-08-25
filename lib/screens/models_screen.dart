import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/llm_model.dart';
import '../services/model_manager.dart';

class ModelsScreen extends StatelessWidget {
  const ModelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ModelManager>(
      builder: (context, modelManager, child) {
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: modelManager.models.length,
          itemBuilder: (context, index) {
            final model = modelManager.models[index];
            return ModelCard(model: model);
          },
        );
      },
    );
  }
}

class ModelCard extends StatelessWidget {
  final LlmModel model;

  const ModelCard({super.key, required this.model});

  @override
  Widget build(BuildContext context) {
    final modelManager = Provider.of<ModelManager>(context, listen: false);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.model_training,
                  color: model.status == ModelStatus.active
                      ? Colors.green
                      : Colors.blue,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _getSizeString(model.size),
                        style: TextStyle(color: Colors.grey[400], fontSize: 14),
                      ),
                    ],
                  ),
                ),
                if (model.status == ModelStatus.active)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Active',
                      style: TextStyle(color: Colors.green, fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(model.description),
            const SizedBox(height: 12),

            // Download progress
            if (model.status == ModelStatus.downloading ||
                model.status == ModelStatus.finalizing)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: model.downloadProgress,
                    backgroundColor: Colors.grey[800],
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    model.status == ModelStatus.downloading
                        ? 'Downloading: ${(model.downloadProgress * 100).toInt()}%'
                        : 'Finalizing...',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                ],
              ),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (model.status == ModelStatus.downloaded ||
                    model.status == ModelStatus.active)
                  OutlinedButton(
                    onPressed: () async {
                      await modelManager.deleteModel(model.id);
                    },
                    child: const Text('Delete'),
                  ),
                const SizedBox(width: 8),
                if (model.status == ModelStatus.notDownloaded ||
                    model.status == ModelStatus.error)
                  ElevatedButton(
                    onPressed: () async {
                      await modelManager.downloadModel(model.id);
                    },
                    child: const Text('Download'),
                  ),
                if (model.status == ModelStatus.downloading)
                  ElevatedButton(
                    onPressed: () async {
                      await modelManager.cancelDownload(model.id);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('Cancel'),
                  ),
                if (model.status == ModelStatus.finalizing)
                  const ElevatedButton(
                    onPressed: null,
                    child: Text('Finalizing...'),
                  ),
                if (model.status == ModelStatus.downloaded)
                  ElevatedButton(
                    onPressed: () async {
                      await modelManager.setActiveModel(model.id);
                    },
                    child: const Text('Activate'),
                  ),
                if (model.status == ModelStatus.active)
                  const ElevatedButton(onPressed: null, child: Text('Active')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getSizeString(int sizeInBytes) {
    if (sizeInBytes < 1024 * 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(2)} KB';
    } else if (sizeInBytes < 1024 * 1024 * 1024) {
      return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(sizeInBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
}
