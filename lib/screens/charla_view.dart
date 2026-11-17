import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../avisos.dart';
import '../board_store.dart';
import '../conexion.dart';
import '../models.dart';
import '../speaker.dart';

/// La charla entre el teléfono de Alejo y el de papá: lo que dijo cada uno, con dibujos. En el teléfono de papá además se
/// graban mensajes de voz y se traen o se mandan los botones de Alejo.
class CharlaView extends StatefulWidget {
  const CharlaView({super.key});

  @override
  State<CharlaView> createState() => _CharlaViewState();
}

class _CharlaViewState extends State<CharlaView> {
  final _grabadora = AudioRecorder();
  final _scroll = ScrollController();
  bool _grabando = false, _ocupado = false;
  int _segundos = 0;
  Timer? _reloj;

  @override
  void dispose() {
    _reloj?.cancel();
    _grabadora.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _aviso(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _grabar() async {
    final conexion = context.read<Conexion>();
    if (_grabando) {
      _reloj?.cancel();
      final ruta = await _grabadora.stop();
      setState(() => _grabando = false);
      if (ruta == null) return;
      setState(() => _ocupado = true);
      final ok = await conexion.mandarArchivo(File(ruta), 'voz.m4a', 'voz');
      setState(() => _ocupado = false);
      _aviso(
        ok ? 'Mensaje de voz enviado' : 'No se pudo mandar (¿hay internet?)',
      );
      return;
    }
    if (!await _grabadora.hasPermission()) {
      _aviso('Para grabar hay que permitir el uso del micrófono.');
      return;
    }
    await Speaker.instance.stop();
    final dir = await getTemporaryDirectory();
    await _grabadora.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: '${dir.path}/voz_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
    setState(() {
      _grabando = true;
      _segundos = 0;
    });
    _reloj = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _segundos++);
      if (_segundos >= 60) _grabar(); // un minuto como máximo
    });
  }

  Future<void> _traerBotones() async {
    setState(() => _ocupado = true);
    final ok = await context.read<Conexion>().pedirTableros();
    setState(() => _ocupado = false);
    _aviso(
      ok
          ? 'Le pedí los botones al teléfono de Alejo: llegan en unos segundos si está prendido y con la app abierta.'
          : 'No se pudo pedir (¿hay internet?)',
    );
  }

  Future<void> _mandarBotones() async {
    final si = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Mandarle tus botones a Alejo?'),
        content: const Text(
          'Los botones, temas, fotos, voces y la agenda de este teléfono van a reemplazar los del teléfono de Alejo.\n\n'
          'Conviene primero traer los de él, cambiar lo que quieras y después mandarlos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Mandar'),
          ),
        ],
      ),
    );
    if (si != true || !mounted) return;
    setState(() => _ocupado = true);
    final store = context.read<BoardStore>();
    final conexion = context.read<Conexion>();
    final paquete = await store.exportarPaquete();
    final tam = await paquete.length();
    if (tam > 14 * 1024 * 1024) {
      setState(() => _ocupado = false);
      _aviso(
        'Son demasiadas fotos para mandar de una vez (${(tam / 1048576).toStringAsFixed(1)} MB; el máximo es 14 MB).',
      );
      return;
    }
    final ok = await conexion.mandarArchivo(
      paquete,
      'botones.json.gz',
      'tableros',
    );
    setState(() => _ocupado = false);
    _aviso(
      ok
          ? 'Botones enviados al teléfono de Alejo'
          : 'No se pudo mandar (¿hay internet?)',
    );
  }

  @override
  Widget build(BuildContext context) {
    final conexion = context.watch<Conexion>();
    final avisos = context.watch<Avisos>();
    final store = context.watch<BoardStore>();
    final mensajes = conexion.charla.reversed.toList();
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: conexion.conectado
              ? const Color(0xFFE8F5E9)
              : const Color(0xFFFFEBEE),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            conexion.conectado
                ? (conexion.esPapa
                      ? '🟢 Conectado con el teléfono de ${avisos.nombre}'
                      : '🟢 Conectado con ${avisos.cuidador}')
                : '🔴 Sin conexión (revisá internet${conexion.esPapa ? ' y el código en ⚙️' : ''})',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        if (conexion.esPapa)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _ocupado ? null : _traerBotones,
                  icon: const Icon(Icons.download),
                  label: Text('Traer los botones de ${avisos.nombre}'),
                ),
                OutlinedButton.icon(
                  onPressed: _ocupado ? null : _mandarBotones,
                  icon: const Icon(Icons.upload),
                  label: Text('Mandarle mis botones'),
                ),
              ],
            ),
          ),
        if (_ocupado) const LinearProgressIndicator(),
        Expanded(
          child: mensajes.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      conexion.esPapa
                          ? 'Acá vas a ver lo que dice ${avisos.nombre}.\nPara contestarle, armá la frase con los dibujos (arriba) y tocá ▶, o grabá tu voz con el micrófono.'
                          : 'Acá aparecen los mensajes de ${avisos.cuidador}.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scroll,
                  reverse: true,
                  padding: const EdgeInsets.all(10),
                  itemCount: mensajes.length,
                  itemBuilder: (_, i) => _Burbuja(
                    m: mensajes[i],
                    store: store,
                    avisos: avisos,
                    esPapa: conexion.esPapa,
                  ),
                ),
        ),
        if (conexion.esPapa)
          Padding(
            padding: const EdgeInsets.all(10),
            child: SizedBox(
              width: double.infinity,
              height: 64,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _grabando ? Colors.red : null,
                ),
                onPressed: _ocupado ? null : _grabar,
                icon: Icon(_grabando ? Icons.stop : Icons.mic, size: 32),
                label: Text(
                  _grabando
                      ? 'Grabando… $_segundos s (tocá para mandar)'
                      : 'Grabar mensaje de voz',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Burbuja extends StatelessWidget {
  const _Burbuja({
    required this.m,
    required this.store,
    required this.avisos,
    required this.esPapa,
  });
  final Mensaje m;
  final BoardStore store;
  final Avisos avisos;
  final bool esPapa;

  @override
  Widget build(BuildContext context) {
    final mio = m.deAlejo != esPapa; // lo mandó este teléfono
    final quien = m.deAlejo ? avisos.nombre : avisos.cuidador;
    String dos(int n) => n.toString().padLeft(2, '0');
    final hora =
        '${dos(m.t.day)}/${dos(m.t.month)} ${dos(m.t.hour)}:${dos(m.t.minute)}';
    Widget contenido;
    if (m.tipo == 'voz') {
      contenido = TextButton.icon(
        onPressed: m.audio != null && File(m.audio!).existsSync()
            ? () => Speaker.instance.say('', audioFile: m.audio)
            : null,
        icon: const Icon(Icons.play_circle, size: 36),
        label: const Text('Mensaje de voz', style: TextStyle(fontSize: 18)),
      );
    } else if (m.tipo == 'tableros') {
      contenido = const Text(
        '🧩 Botones enviados',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      );
    } else {
      final partes = store.pictosDeFrase(m.texto);
      contenido = InkWell(
        onTap: () => Speaker.instance.say(m.texto),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (palabra, p) in partes)
              _Palabra(palabra: palabra, picto: p, store: store),
          ],
        ),
      );
    }
    return Align(
      alignment: mio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * .85,
        ),
        decoration: BoxDecoration(
          color: m.deAlejo ? const Color(0xFFE3F2FD) : const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$quien · $hora',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            contenido,
          ],
        ),
      ),
    );
  }
}

class _Palabra extends StatelessWidget {
  const _Palabra({
    required this.palabra,
    required this.picto,
    required this.store,
  });
  final String palabra;
  final Pictogram? picto;
  final BoardStore store;
  @override
  Widget build(BuildContext context) {
    final f = store.mediaFile(picto?.imagePath);
    final img = f != null && File(f).existsSync()
        ? ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(f),
              width: 54,
              height: 54,
              fit: BoxFit.cover,
            ),
          )
        : (picto != null && picto!.emoji.isNotEmpty
              ? Text(picto!.emoji, style: const TextStyle(fontSize: 34))
              : null);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ?img,
        Text(
          palabra,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}
