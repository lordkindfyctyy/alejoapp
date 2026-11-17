import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'avisos.dart';
import 'board_store.dart';
import 'default_boards.dart';
import 'edit_mode.dart';
import 'screens/agenda_view.dart';
import 'screens/ajustes_screen.dart';
import 'screens/board_view.dart';
import 'screens/categories_view.dart';
import 'screens/feelings_view.dart';
import 'screens/talking_view.dart';
import 'sentence.dart';
import 'widgets/core_words_bar.dart';
import 'widgets/sentence_bar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationDocumentsDirectory();
  final store = BoardStore(dir);
  await store.load();
  final avisos = Avisos(dir);
  await avisos.load();
  runApp(AlejoApp(store: store, avisos: avisos));
}

class AlejoApp extends StatelessWidget {
  const AlejoApp({super.key, required this.store, this.sentence, this.avisos});

  final BoardStore store;

  /// Avisos al celular de papá (los tests pasan uno que no usa internet).
  final Avisos? avisos;

  /// Los tests pasan una que no usa la voz del teléfono.
  final Sentence? sentence;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider.value(
          value: avisos ?? Avisos(store.root, enviarHttp: (_) async => false),
        ),
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
          // con 5 solapas, letra un poco más chica abajo para que "Categorías" entre en un renglón
          navigationBarTheme: const NavigationBarThemeData(
            labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
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

/// Paneles: inicio, categorías, cómo me siento, agenda y "yo hablo".
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
          editing
              ? 'Modo edición'
              : const [
                  'INICIO',
                  'TEMAS',
                  'ME SIENTO',
                  'AGENDA',
                  'YO HABLO',
                ][_tab],
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        actions: [
          if (editing)
            IconButton(
              tooltip: 'Ajustes y avisos',
              icon: const Icon(Icons.settings, size: 30),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AjustesScreen()),
              ),
            ),
          EditModeButton(mode: context.read<EditMode>()),
        ],
      ),
      body: Column(
        children: [
          // La frase sigue armada al pasar de Inicio a una categoría y volver.
          const SentenceBar(),
          if (_tab != 4) const EditHint(),
          if (_tab <= 1 && !editing) const CoreWordsBar(),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: const [
                BoardView(boardId: kHomeBoardId),
                CategoriesView(),
                FeelingsView(),
                AgendaView(),
                TalkingView(),
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
            label: 'Temas',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline, size: 32),
            selectedIcon: Icon(Icons.favorite, size: 32),
            label: 'Me siento',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined, size: 32),
            selectedIcon: Icon(Icons.event_note, size: 32),
            label: 'Agenda',
          ),
          NavigationDestination(
            icon: Icon(Icons.record_voice_over_outlined, size: 32),
            selectedIcon: Icon(Icons.record_voice_over, size: 32),
            label: 'Yo hablo',
          ),
        ],
      ),
    );
  }
}
