import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'board_store.dart';
import 'default_boards.dart';
import 'edit_mode.dart';
import 'screens/board_view.dart';
import 'screens/categories_view.dart';
import 'sentence.dart';
import 'widgets/sentence_bar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationDocumentsDirectory();
  final store = BoardStore(dir);
  await store.load();
  runApp(AlejoApp(store: store));
}

class AlejoApp extends StatelessWidget {
  const AlejoApp({super.key, required this.store, this.sentence});

  final BoardStore store;

  /// Los tests pasan una que no usa la voz del teléfono.
  final Sentence? sentence;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider(create: (_) => EditMode()),
        ChangeNotifierProvider(create: (_) => sentence ?? Sentence()),
      ],
      child: MaterialApp(
        title: 'AlejoApp',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2E7DD7),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFF4F7FB),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF2E7DD7),
            foregroundColor: Colors.white,
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

/// Dos paneles: el tablero de inicio y las categorías.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final editing = context.watch<EditMode>().editing;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        backgroundColor: editing ? const Color(0xFFE07A00) : null,
        title: Text(
          editing ? 'Modo edición' : (_tab == 0 ? 'INICIO' : 'CATEGORÍAS'),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        actions: [EditModeButton(mode: context.read<EditMode>())],
      ),
      body: Column(
        children: [
          // La frase sigue armada al pasar de Inicio a una categoría y volver.
          const SentenceBar(),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: const [
                BoardView(boardId: kHomeBoardId),
                CategoriesView(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        height: 72,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, size: 32),
            selectedIcon: Icon(Icons.home, size: 32),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined, size: 32),
            selectedIcon: Icon(Icons.grid_view, size: 32),
            label: 'Categorías',
          ),
        ],
      ),
    );
  }
}
