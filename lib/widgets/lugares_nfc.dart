import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../avisos.dart';
import '../board_store.dart';
import '../conexion.dart';
import '../speaker.dart';
import '../stickers_nfc.dart';

/// Cuando Alejo apoya el celular en un sticker NFC de la casa (heladera, baño, cama...), muestra ese pictograma en
/// grande, lo dice en voz alta (o suena la voz grabada del botón) y, si los avisos están activos, le llega a papá.
/// Funciona si el sticker abrió la app (linkInicial) o si la app ya estaba abierta (toques).
class LugaresNfc extends StatefulWidget {
  const LugaresNfc({super.key, required this.child});
  final Widget child;

  @override
  State<LugaresNfc> createState() => _LugaresNfcState();
}

class _LugaresNfcState extends State<LugaresNfc> {
  StreamSubscription<String>? _sub;
  bool _mostrando = false;
  int _vez =
      0; // para que el cierre de uno viejo no marque como cerrado al nuevo

  @override
  void initState() {
    super.initState();
    _sub = StickersNfc.instancia.toques.listen(_atender);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final link = await StickersNfc.instancia.linkInicial();
      if (link != null) _atender(link);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _atender(String link) async {
    final datos = StickersNfc.leer(link);
    if (datos == null || !mounted) return;
    final store = context.read<BoardStore>();
    final picto = store.pictogramaDeSticker(datos.id, datos.nombre);
    final nombre = picto?.label ?? datos.nombre;
    if (nombre.isEmpty) return;

    Speaker.instance.say(nombre, audioFile: store.mediaFile(picto?.audioPath));
    // A papá le llega como cualquier frase de Alejo (si tiene activado "cada frase")
    if (!context.read<Conexion>().esPapa) {
      context.read<Avisos>().decir(nombre, esFrase: true);
    }

    // Si ya había uno en pantalla (tocó otro sticker), se cambia por el nuevo
    final navegador = Navigator.of(context, rootNavigator: true);
    if (_mostrando) navegador.pop();
    _mostrando = true;
    final mia = ++_vez;
    final foto = store.mediaFile(picto?.imagePath);
    final hayFoto = foto != null && File(foto).existsSync();
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (c) => Dialog(
        insetPadding: const EdgeInsets.all(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hayFoto)
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.file(
                    File(foto),
                    width: 260,
                    height: 260,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Text(
                  picto != null && picto.emoji.isNotEmpty ? picto.emoji : '🏠',
                  style: const TextStyle(fontSize: 150),
                ),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  nombre,
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Speaker.instance.say(
                        nombre,
                        audioFile: store.mediaFile(picto?.audioPath),
                      ),
                      icon: const Icon(Icons.volume_up, size: 30),
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
    if (mia == _vez) _mostrando = false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
