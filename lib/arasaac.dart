import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

/// Pictogramas de ARASAAC (https://arasaac.org): la biblioteca de pictogramas que se usa en escuelas y terapias.
/// Se buscan por palabra en castellano y el elegido se descarga una vez; después queda guardado en el teléfono y anda
/// sin internet.
///
/// Licencia: CC BY-NC-SA 4.0 (se pueden usar gratis, sin fines comerciales y citando la autoría).
class Arasaac {
  static const autoria =
      'Pictogramas: Sergio Palao. Origen: ARASAAC (https://arasaac.org). Licencia: CC BY-NC-SA 4.0. '
      'Propiedad: Gobierno de Aragón (España).';

  static String imagen(int id, {int tam = 300}) =>
      'https://static.arasaac.org/pictograms/$id/${id}_$tam.png';

  static Future<List<int>> buscar(String palabra) async {
    final p = palabra.trim().toLowerCase();
    if (p.isEmpty) return [];
    final cliente = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await cliente.getUrl(
        Uri.parse(
          'https://api.arasaac.org/v1/pictograms/es/search/${Uri.encodeComponent(p)}',
        ),
      );
      final res = await req.close().timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        await res.drain<void>();
        return [];
      }
      final lista =
          jsonDecode(await res.transform(utf8.decoder).join()) as List;
      return [for (final x in lista.take(30)) (x as Map)['_id'] as int];
    } finally {
      cliente.close(force: true);
    }
  }

  /// Descarga el pictograma a un archivo temporal (el editor después lo copia a la carpeta de la app).
  static Future<File> descargar(int id) async {
    final cliente = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await cliente.getUrl(Uri.parse(imagen(id, tam: 500)));
      final res = await req.close().timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        throw HttpException('ARASAAC respondió ${res.statusCode}');
      }
      final bytes = <int>[];
      await for (final parte in res) {
        bytes.addAll(parte);
      }
      final f = File('${Directory.systemTemp.path}/arasaac_$id.png');
      await f.writeAsBytes(bytes, flush: true);
      return f;
    } finally {
      cliente.close(force: true);
    }
  }
}

/// Buscador de pictogramas de ARASAAC. Devuelve el archivo descargado del elegido, o null.
Future<File?> elegirPictogramaArasaac(
  BuildContext context,
  String palabraInicial,
) {
  return showDialog<File>(
    context: context,
    builder: (_) => _BuscadorArasaac(palabraInicial),
  );
}

class _BuscadorArasaac extends StatefulWidget {
  const _BuscadorArasaac(this.inicial);
  final String inicial;
  @override
  State<_BuscadorArasaac> createState() => _BuscadorArasaacState();
}

class _BuscadorArasaacState extends State<_BuscadorArasaac> {
  late final _texto = TextEditingController(text: widget.inicial);
  List<int> _ids = [];
  bool _buscando = false, _bajando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.inicial.trim().isNotEmpty) _buscar();
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    setState(() {
      _buscando = true;
      _error = null;
    });
    try {
      final ids = await Arasaac.buscar(_texto.text);
      setState(() {
        _ids = ids;
        if (ids.isEmpty) {
          _error =
              'No encontré pictogramas para "${_texto.text}". Probá con otra palabra.';
        }
      });
    } catch (e) {
      setState(() => _error = 'No pude buscar: ¿hay internet?');
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  Future<void> _elegir(int id) async {
    setState(() => _bajando = true);
    try {
      final f = await Arasaac.descargar(id);
      if (mounted) Navigator.pop(context, f);
    } catch (e) {
      if (mounted) {
        setState(() {
          _bajando = false;
          _error = 'No pude descargarlo: ¿hay internet?';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pictogramas ARASAAC'),
      content: SizedBox(
        width: 480,
        height: 520,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _texto,
                    decoration: const InputDecoration(
                      hintText: 'Palabra (ej: agua, jugar, mamá)',
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _buscar(),
                  ),
                ),
                IconButton(onPressed: _buscar, icon: const Icon(Icons.search)),
              ],
            ),
            const SizedBox(height: 8),
            if (_buscando || _bajando) const LinearProgressIndicator(),
            if (_error != null)
              Padding(padding: const EdgeInsets.all(8), child: Text(_error!)),
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  for (final id in _ids)
                    InkWell(
                      onTap: _bajando ? null : () => _elegir(id),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black12),
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.white,
                        ),
                        padding: const EdgeInsets.all(6),
                        child: Image.network(
                          Arasaac.imagen(id),
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.image_not_supported),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Text(
              Arasaac.autoria,
              style: TextStyle(fontSize: 10, color: Colors.black54),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
