import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/chat_screen.dart';
import 'screens/models_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/info_screen.dart';
import 'services/model_manager.dart';
import 'services/chat_storage.dart';
import 'services/llm_service.dart';
import 'widgets/navigation_drawer.dart' as nav;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Ініціалізація сервісів
  final chatStorage = ChatStorage();
  await chatStorage.init();
  
  final modelManager = ModelManager();
  await modelManager.init();
  
  final llmService = LlmService();
  await llmService.init();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => chatStorage),
        ChangeNotifierProvider(create: (_) => modelManager),
        Provider(create: (_) => llmService),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Local LLM Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.grey[900],
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const AppScaffold(initialIndex: 0),
    );
  }
}

class AppScaffold extends StatefulWidget {
  final int initialIndex;

  const AppScaffold({super.key, required this.initialIndex});

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  late int _selectedIndex;
  
  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  final List<Widget> _screens = [
    const ChatScreen(),
    const ModelsScreen(),
    const SettingsScreen(),
    const InfoScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      drawer: nav.NavigationDrawer(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
}