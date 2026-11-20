import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'avisos.dart';
import 'board_store.dart';
import 'conexion.dart';
import 'default_boards.dart';
import 'edit_mode.dart';
import 'screens/agenda_view.dart';
import 'screens/ajustes_screen.dart';
import 'screens/board_view.dart';
import 'screens/charla_view.dart';
import 'screens/categories_view.dart';
import 'screens/feelings_view.dart';
import 'screens/talking_view.dart';
import 'sentence.dart';
import 'widgets/core_words_bar.dart';
import 'widgets/lugares_nfc.dart';
import 'widgets/receptor.dart';
import 'widgets/sentence_bar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationDocumentsDirectory();
  final store = BoardStore(dir);
  await store.load();
  final avisos = Avisos(dir);
  await avisos.load();
  final conexion = Conexion(dir, avisos);
  await conexion.load();
  runApp(AlejoApp(store: store, avisos: avisos, conexion: conexion));
}

class AlejoApp extends StatelessWidget {
  const AlejoApp({
    super.key,
    required this.store,
    this.sentence,
    this.avisos,
    this.conexion,
  });

  final BoardStore store;

  /// Avisos al celular de papá (los tests pasan uno que no usa internet).
  final Avisos? avisos;

  /// Conexión con el teléfono de papá (los tests no la pasan: queda sin conectar).
  final Conexion? conexion;

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
        ChangeNotifierProvider(
          create: (c) =>
              conexion ?? Conexion(store.root, c.read<Avisos>(), sinRed: true),
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
            labelTextStyle: WidgetStatePropertyAll(
              TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
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

class _Solapa {
  const _Solapa(
    this.titulo,
    this.etiqueta,
    this.icono,
    this.iconoActivo,
    this.pantalla, {
    this.conPalabras = false,
    this.conAyuda = true,
  });
  final String titulo, etiqueta;
  final IconData icono, iconoActivo;
  final Widget pantalla;
  final bool conPalabras, conAyuda;
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  // El teléfono de Alejo y el de papá muestran solapas distintas.
  static const _deAlejo = [
    _Solapa(
      'INICIO',
      'Inicio',
      Icons.home_outlined,
      Icons.home,
      BoardView(boardId: kHomeBoardId),
      conPalabras: true,
    ),
    _Solapa(
      'TEMAS',
      'Temas',
      Icons.grid_view_outlined,
      Icons.grid_view,
      CategoriesView(),
      conPalabras: true,
    ),
    _Solapa(
      'ME SIENTO',
      'Me siento',
      Icons.favorite_outline,
      Icons.favorite,
      FeelingsView(),
    ),
    _Solapa(
      'AGENDA',
      'Agenda',
      Icons.event_note_outlined,
      Icons.event_note,
      AgendaView(),
    ),
    _Solapa(
      'YO HABLO',
      'Yo hablo',
      Icons.record_voice_over_outlined,
      Icons.record_voice_over,
      TalkingView(),
      conAyuda: false,
    ),
  ];
  static const _dePapa = [
    _Solapa(
      'INICIO',
      'Inicio',
      Icons.home_outlined,
      Icons.home,
      BoardView(boardId: kHomeBoardId),
    ),
    _Solapa(
      'TEMAS',
      'Temas',
      Icons.grid_view_outlined,
      Icons.grid_view,
      CategoriesView(),
    ),
    _Solapa(
      'AGENDA',
      'Agenda',
      Icons.event_note_outlined,
      Icons.event_note,
      AgendaView(),
    ),
    _Solapa(
      'CHARLA',
      'Charla',
      Icons.forum_outlined,
      Icons.forum,
      CharlaView(),
      conAyuda: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final editing = context.watch<EditMode>().editing;
    final esPapa = context.watch<Conexion>().esPapa;
    final solapas = esPapa ? _dePapa : _deAlejo;
    final tab = _tab.clamp(0, solapas.length - 1);
    final s = solapas[tab];
    return LugaresNfc(
      child: Receptor(
        child: Scaffold(
          appBar: AppBar(
            toolbarHeight: 64,
            backgroundColor: editing
                ? const Color(0xFFE07A00)
                : (esPapa ? const Color(0xFF5B5FC7) : null),
            title: Text(
              editing
                  ? 'Modo edición'
                  : (esPapa ? '${s.titulo} · PAPÁ' : s.titulo),
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
              // La frase sigue armada al pasar de una solapa a otra.
              const SentenceBar(),
              if (s.conAyuda) const EditHint(),
              if (s.conPalabras && !editing) const CoreWordsBar(),
              Expanded(
                child: IndexedStack(
                  index: tab,
                  children: [for (final x in solapas) x.pantalla],
                ),
              ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            height: 72,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: [
              for (final x in solapas)
                NavigationDestination(
                  icon: Icon(x.icono, size: 32),
                  selectedIcon: Icon(x.iconoActivo, size: 32),
                  label: x.etiqueta,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
