import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/llm_model.dart';
import '../services/llm_service.dart';
import '../services/chat_storage.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _contextLength = 2048;
  bool _saveChatHistory = true;
  QuantizationType _defaultQuantization = QuantizationType.bit4;
  
  late SharedPreferences _prefs;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    
    setState(() {
      _contextLength = _prefs.getInt('context_length') ?? 2048;
      _saveChatHistory = _prefs.getBool('save_chat_history') ?? true;
      _defaultQuantization = _prefs.getInt('default_quantization') == 8
          ? QuantizationType.bit8
          : QuantizationType.bit4;
      _isLoading = false;
    });
  }
  
  Future<void> _saveSettings() async {
    await _prefs.setInt('context_length', _contextLength);
    await _prefs.setBool('save_chat_history', _saveChatHistory);
    await _prefs.setInt(
      'default_quantization', 
      _defaultQuantization == QuantizationType.bit8 ? 8 : 4
    );
    
    // Оновлення сервісу LLM з новими налаштуваннями
    if (mounted) {
      final llmService = Provider.of<LlmService>(context, listen: false);
      llmService.setContextLength(_contextLength);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Налаштування збережено'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
  
  void _showClearDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Видалити всі чати?'),
        content: const Text('Ця дія незворотня. Всі чати будуть видалені.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Скасувати'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              if (mounted) {
                final chatStorage = Provider.of<ChatStorage>(
                  context, 
                  listen: false
                );
                chatStorage.clearAllChats();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Всі чати видалено'),
                  ),
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Видалити'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Налаштування'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Контекст',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Довжина контексту: $_contextLength токенів',
                    style: TextStyle(color: Colors.grey[300]),
                  ),
                  Slider(
                    value: _contextLength.toDouble(),
                    min: 512,
                    max: 4096,
                    divisions: 7,
                    label: _contextLength.toString(),
                    onChanged: (value) {
                      setState(() {
                        _contextLength = value.toInt();
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Більший контекст дозволяє моделі "пам\'ятати" більше тексту, але використовує більше пам\'яті та може працювати повільніше.',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
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
                    'Квантизація моделі',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  RadioListTile<QuantizationType>(
                    title: const Text('4-bit (швидше, але менш точно)'),
                    value: QuantizationType.bit4,
                    groupValue: _defaultQuantization,
                    onChanged: (value) {
                      setState(() {
                        _defaultQuantization = value!;
                      });
                    },
                  ),
                  RadioListTile<QuantizationType>(
                    title: const Text('8-bit (точніше, але повільніше)'),
                    value: QuantizationType.bit8,
                    groupValue: _defaultQuantization,
                    onChanged: (value) {
                      setState(() {
                        _defaultQuantization = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Це налаштування за замовчуванням для нових моделей. Нижча бітність (4-bit) означає менше використання пам\'яті, але може знизити якість відповідей.',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
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
                    'Історія чатів',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Зберігати історію чатів'),
                    subtitle: Text(
                      'Історія чатів буде збережена між сесіями',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                    value: _saveChatHistory,
                    onChanged: (value) {
                      setState(() {
                        _saveChatHistory = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _showClearDialog,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('Видалити всі чати'),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          ElevatedButton(
            onPressed: _saveSettings,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Зберегти налаштування'),
          ),
        ],
      ),
    );
  }
}