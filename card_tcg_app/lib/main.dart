import 'package:flutter/material.dart';
import 'screens/scan_screen.dart';
import 'screens/collection_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CardTCGApp());
}

class CardTCGApp extends StatelessWidget {
  const CardTCGApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Card TCG Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2B6CB0),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF1A202C),
        cardColor: const Color(0xFF2D3748),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2D3748),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF4A5568)),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF2B6CB0), width: 2),
          ),
        ),
      ),
      home: const _Home(),
    );
  }
}

class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  int _index = 0;

  static const _screens = [
    ScanScreen(),
    CollectionScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: const Color(0xFF2D3748),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.camera_alt_outlined),
            selectedIcon: Icon(Icons.camera_alt),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.collections_outlined),
            selectedIcon: Icon(Icons.collections),
            label: 'Collection',
          ),
        ],
      ),
    );
  }
}
