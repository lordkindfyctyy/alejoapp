import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../avisos.dart';
import '../board_store.dart';
import '../conexion.dart';
import '../speaker.dart';

/// Atiende lo que llega del otro teléfono:
/// - en el de Alejo: los mensajes de papá aparecen en grande y se dicen en voz alta (o suena su voz grabada); si papá
///   manda botones nuevos se aplican; si los pide, se los manda.
/// - en el de papá: lo que dice Alejo suena y aparece arriba; los botones de Alejo que pidió se cargan en este teléfono.
/// También mantiene la conexión abierta mientras la app está en uso.
class Receptor extends StatefulWidget {
  const Receptor({super.key, required this.child});
  final Widget child;

  @override
  State<Receptor> createState() => _ReceptorState();
}

class _ReceptorState extends State<Receptor> with WidgetsBindingObserver {
  StreamSubscription<Llegada>? _sub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final conexion = context.read<Conexion>();
    _sub = conexion.llegadas.listen(_atender);
    conexion.iniciar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // al volver a la app se reconecta y trae lo que llegó mientras tanto
    if (state == AppLifecycleState.resumed) {
      context.read<Conexion>().reiniciar();
    }
  }

  void _aviso(String t) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t), duration: const Duration(seconds: 4)),
      );
    }
  }

  Future<void> _atender(Llegada l) async {
    final conexion = context.read<Conexion>();
    final store = context.read<BoardStore>();
    final avisos = context.read<Avisos>();
    final m = l.mensaje;
    switch (m.tipo) {
      case 'pedir':
        // papá pidió los botones de Alejo: se los manda este teléfono
        if (!conexion.esPapa) {
          final paquete = await store.exportarPaquete();
          await conexion.mandarArchivo(paquete, 'botones.json.gz', 'tableros');
        }
      case 'tableros':
        if (l.adjuntoUrl == null) return;
        final f = await conexion.bajar(l.adjuntoUrl!, 'botones.json.gz');
        if (f == null) {
          _aviso('Llegaron botones pero no se pudieron bajar (¿hay internet?)');
          return;
        }
        await store.importarPaquete(f);
        _aviso(
          conexion.esPapa
              ? 'Listo: tenés los botones de ${avisos.nombre} en este teléfono'
              : '${avisos.cuidador} te mandó botones nuevos',
        );
        if (!conexion.esPapa) {
          Speaker.instance.say('${avisos.cuidador} te mandó botones nuevos');
        }
      case 'voz':
        if (l.adjuntoUrl == null) return;
        final f = await conexion.bajar(
          l.adjuntoUrl!,
          l.adjuntoNombre ?? 'voz.m4a',
        );
        if (f == null) return;
        m.audio = f.path;
        await conexion.anotar(m);
        await _mostrar(
          titulo:
              '${conexion.esPapa ? avisos.nombre : avisos.cuidador} te mandó un mensaje de voz',
          audio: f,
        );
      default:
        if (conexion.esPapa) {
          // lo que dijo Alejo
          Speaker.instance.say(m.texto);
          _aviso('${avisos.nombre}: ${m.texto}');
        } else {
          await _mostrar(titulo: '${avisos.cuidador} DICE', frase: m.texto);
        }
    }
  }

  /// Mensaje en grande en el teléfono de Alejo (o de voz en cualquiera de los dos).
  Future<void> _mostrar({
    required String titulo,
    String? frase,
    File? audio,
  }) async {
    if (!mounted) return;
    final store = context.read<BoardStore>();
    final avisos = context.read<Avisos>();
    final papa = store
        .todosLosPictogramas()
        .where((p) => p.label == avisos.cuidador)
        .firstOrNull;
    final fotoPapa = store.mediaFile(papa?.imagePath);
    void sonar() => audio != null
        ? Speaker.instance.say('', audioFile: audio.path)
        : Speaker.instance.say(frase ?? '');
    sonar();
    await showDialog<void>(
      context: context,
      builder: (c) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (fotoPapa != null && File(fotoPapa).existsSync())
                ClipRRect(
                  borderRadius: BorderRadius.circular(60),
                  child: Image.file(
                    File(fotoPapa),
                    width: 110,
                    height: 110,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Text(
                  papa?.emoji.isNotEmpty == true ? papa!.emoji : '👨',
                  style: const TextStyle(fontSize: 72),
                ),
              const SizedBox(height: 8),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              if (frase != null)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final (palabra, p) in store.pictosDeFrase(frase))
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (store.mediaFile(p?.imagePath) != null &&
                              File(store.mediaFile(p?.imagePath)!).existsSync())
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                File(store.mediaFile(p!.imagePath)!),
                                width: 84,
                                height: 84,
                                fit: BoxFit.cover,
                              ),
                            )
                          else if (p != null && p.emoji.isNotEmpty)
                            Text(p.emoji, style: const TextStyle(fontSize: 56)),
                          Text(
                            palabra,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              if (audio != null)
                const Icon(
                  Icons.graphic_eq,
                  size: 64,
                  color: Color(0xFF2E7DD7),
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: sonar,
                      icon: const Icon(Icons.replay, size: 30),
                      label: const Text(
                        'Otra vez',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text(
                        'OK',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
