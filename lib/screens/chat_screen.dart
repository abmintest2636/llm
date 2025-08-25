import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import '../models/chat_model.dart';
import '../services/chat_storage.dart';
import '../services/llm_service.dart';
import '../services/model_manager.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/navigation_drawer.dart' as nav;
import 'models_screen.dart';
import 'settings_screen.dart';
import 'info_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Chat? _currentChat;
  bool _isGenerating = false;
  String? _currentStreamId;
  String _currentGeneratedText = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatStorage = Provider.of<ChatStorage>(context, listen: false);
      if (chatStorage.chats.isEmpty) {
        _createNewChat();
      } else {
        setState(() {
          _currentChat = chatStorage.chats.first;
        });
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _stopGeneration();
    super.dispose();
  }

  void _createNewChat() async {
    final chatStorage = Provider.of<ChatStorage>(context, listen: false);
    final newChat = await chatStorage.createChat('New Chat');
    setState(() {
      _currentChat = newChat;
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _stopGeneration() {
    if (_currentStreamId != null) {
      final llmService = Provider.of<LlmService>(context, listen: false);
      llmService.stopGeneration(_currentStreamId!);
      _currentStreamId = null;
    }
  }

  Future<void> _sendMessage() async {
    if (_textController.text.trim().isEmpty) return;
    
    final message = _textController.text.trim();
    _textController.clear();
    
    final chatStorage = Provider.of<ChatStorage>(context, listen: false);
    final modelManager = Provider.of<ModelManager>(context, listen: false);
    final llmService = Provider.of<LlmService>(context, listen: false);
    
    if (_currentChat == null) return;
    
    await chatStorage.addMessage(_currentChat!.id!, message, true);
    _scrollToBottom();
    
    if (modelManager.activeModel == null) {
      await chatStorage.addMessage(
        _currentChat!.id!, 
        "Error: Please load and activate a model in the 'Models' section first.",
        false
      );
      _scrollToBottom();
      return;
    }
    
    setState(() {
      _isGenerating = true;
      _currentGeneratedText = "";
    });
    
    try {
      await chatStorage.addMessage(_currentChat!.id!, "", false);
      _currentStreamId = DateTime.now().millisecondsSinceEpoch.toString();
      
      llmService.generateResponseStream(message).listen(
        (generatedPiece) async {
          setState(() {
            _currentGeneratedText = generatedPiece;
          });
          
          final chat = chatStorage.getChatById(_currentChat!.id!);
          if (chat != null && chat.messages.isNotEmpty) {
            final lastMessage = chat.messages.last;
            await chatStorage.updateMessage(lastMessage.id!, generatedPiece);
          }
          
          _scrollToBottom();
        },
        onDone: () {
          setState(() {
            _isGenerating = false;
            _currentStreamId = null;
          });
        },
        onError: (error) async {
          await chatStorage.addMessage(
            _currentChat!.id!, 
            "Error generating response: $error",
            false
          );
          setState(() {
            _isGenerating = false;
            _currentStreamId = null;
          });
          _scrollToBottom();
        },
      );
    } catch (e) {
      await chatStorage.addMessage(
        _currentChat!.id!, 
        "Error generating response: ${e.toString()}",
        false
      );
      setState(() {
        _isGenerating = false;
        _currentStreamId = null;
      });
      _scrollToBottom();
    }
  }

  void _onItemTapped(int index) {
    Navigator.pop(context); // Close the drawer
    if (index == 0) return; // Already on chat screen

    Widget page;
    switch (index) {
      case 1:
        page = const ModelsScreen();
        break;
      case 2:
        page = const SettingsScreen();
        break;
      case 3:
        page = const InfoScreen();
        break;
      default:
        return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentChat?.title ?? 'Chat'),
        actions: [
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              if (_currentChat != null) ...[
                PopupMenuItem(
                  onTap: () async {
                    final chatStorage = Provider.of<ChatStorage>(context, listen: false);
                    await chatStorage.archiveChat(_currentChat!.id!, true);
                    if (chatStorage.chats.isNotEmpty) {
                      setState(() {
                        _currentChat = chatStorage.chats.first;
                      });
                    } else {
                      _createNewChat();
                    }
                  },
                  child: const Text('Archive Chat'),
                ),
                PopupMenuItem(
                  onTap: () async {
                    final chatStorage = Provider.of<ChatStorage>(context, listen: false);
                    await chatStorage.deleteChat(_currentChat!.id!);
                    if (chatStorage.chats.isNotEmpty) {
                      setState(() {
                        _currentChat = chatStorage.chats.first;
                      });
                    } else {
                      _createNewChat();
                    }
                  },
                  child: const Text('Delete Chat'),
                ),
              ],
              PopupMenuItem(
                onTap: _createNewChat,
                child: const Text('New Chat'),
              ),
            ],
          ),
        ],
      ),
      drawer: nav.NavigationDrawer(
        selectedIndex: 0,
        onItemTapped: _onItemTapped,
      ),
      body: Column(
        children: [
          Container(
            height: 50,
            color: Colors.grey[900],
            child: Consumer<ChatStorage>(
              builder: (context, chatStorage, child) {
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: chatStorage.chats.length,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemBuilder: (context, index) {
                    final chat = chatStorage.chats[index];
                    final isSelected = chat.id == _currentChat?.id;
                    
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _currentChat = chat;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 4, 
                          vertical: 8,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isSelected 
                            ? Colors.blue.shade800 
                            : Colors.grey.shade800,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          chat.title,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[300],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          Expanded(
            child: Consumer<ChatStorage>(
              builder: (context, chatStorage, child) {
                if (_currentChat == null) {
                  return const Center(
                    child: Text('Create a new chat to start talking'),
                  );
                }
                
                final chat = chatStorage.getChatById(_currentChat!.id!);
                if (chat == null) {
                  return const Center(
                    child: Text('Chat not found'),
                  );
                }
                
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(top: 16, bottom: 80),
                  itemCount: chat.messages.length,
                  itemBuilder: (context, index) {
                    final message = chat.messages[index];
                    
                    if (index == chat.messages.length - 1 && 
                        !message.isUser && 
                        _isGenerating) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _currentGeneratedText.isEmpty
                                ? AnimatedTextKit(
                                    animatedTexts: [
                                      WavyAnimatedText(
                                        'Generating response...',
                                        textStyle: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                    isRepeatingAnimation: true,
                                    totalRepeatCount: 100,
                                  )
                                : Text(
                                    _currentGeneratedText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                    ),
                                  ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTime(DateTime.now()),
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    
                    return ChatBubble(message: message);
                  },
                );
              },
            ),
          ),
          
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  spreadRadius: 2,
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: 'Write a message...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      filled: true,
                      fillColor: Colors.grey[800],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _isGenerating ? null : _sendMessage(),
                    maxLines: null,
                    enabled: !_isGenerating,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: _isGenerating ? Colors.red : Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      _isGenerating ? Icons.stop : Icons.send,
                      color: Colors.white,
                    ),
                    onPressed: _isGenerating ? _stopGeneration : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}