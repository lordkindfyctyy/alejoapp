import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../board_store.dart';
import '../models.dart';
import '../stickers_nfc.dart';

/// Sección de Ajustes: stickers NFC de la casa. Se elige un pictograma (HELADERA, BAÑO, CAMA...) y se graba en un
/// sticker. Después, cuando Alejo apoya el celular en el sticker, la app muestra ese pictograma en grande y lo dice
/// (widgets/lugares_nfc.dart).
class StickersNfcAjustes extends StatefulWidget {
  const StickersNfcAjustes({super.key});

  @override
  State<StickersNfcAjustes> createState() => _StickersNfcAjustesState();
}

class _StickersNfcAjustesState extends State<StickersNfcAjustes> {
  String _estado = '…';

  @override
  void initState() {
    super.initState();
    _revisar();
  }

  Future<void> _revisar() async {
    final e = await StickersNfc.instancia.estado();
    if (mounted) setState(() => _estado = e);
  }

  Future<void> _grabar() async {
    final store = context.read<BoardStore>();
    final picto = await showDialog<Pictogram>(
      context: context,
      builder: (_) => _ElegirPicto(store: store),
    );
    if (picto == null || !mounted) return;
    final mensajero = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context);
    // Mientras espera el sticker: el pictograma elegido y "Cancelar"
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: Text('Grabar: ${picto.label}'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('📲', style: TextStyle(fontSize: 64)),
            SizedBox(height: 8),
            Text(
              'Apoyá el sticker en la parte de atrás del celular y dejalo quieto hasta que diga listo.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 14),
            LinearProgressIndicator(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => StickersNfc.instancia.cancelar(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    final resultado = await StickersNfc.instancia.grabar(picto);
    navegador.pop(); // cierra el cartel de espera
    if (resultado == 'cancelado') return;
    mensajero.showSnackBar(
      SnackBar(
        content: Text(
          resultado == 'ok'
              ? '✅ Listo: el sticker dice ${picto.label}. Pegalo en su lugar.'
              : resultado,
          style: const TextStyle(fontSize: 16),
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final explicacion = switch (_estado) {
      'sin' =>
        'Este teléfono no tiene NFC: los stickers no van a funcionar acá.',
      'apagado' => 'El NFC está apagado. Prendelo en los ajustes del teléfono (Conexiones → NFC) y tocá Revisar.',
      'listo' => 'NFC prendido ✓',
      _ => 'Revisando NFC…',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🏷️ Stickers de la casa (NFC)',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        const Text(
          'Pegá un sticker NFC en la heladera, el baño, la cama... Grabale el pictograma que corresponde y, cuando '
          'Alejo apoye el celular, la app se abre sola, muestra la foto en grande y la dice. Si los avisos están '
          'activos, también te llega a vos.',
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              _estado == 'listo' ? Icons.nfc : Icons.info_outline,
              color: _estado == 'listo' ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                explicacion,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (_estado != 'listo')
              TextButton(onPressed: _revisar, child: const Text('Revisar')),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _estado == 'listo' ? _grabar : null,
          icon: const Icon(Icons.edit_note),
          label: const Text('Grabar un sticker'),
        ),
      ],
    );
  }
}

/// Todos los pictogramas para elegir cuál grabar, con buscador.
class _ElegirPicto extends StatefulWidget {
  const _ElegirPicto({required this.store});
  final BoardStore store;

  @override
  State<_ElegirPicto> createState() => _ElegirPictoState();
}

class _ElegirPictoState extends State<_ElegirPicto> {
  String _buscar = '';

  @override
  Widget build(BuildContext context) {
    final todos = widget.store.todosLosPictogramas();
    final filtro = _buscar.trim().toUpperCase();
    final lista = filtro.isEmpty
        ? todos
        : todos.where((p) => p.label.toUpperCase().contains(filtro)).toList();
    return AlertDialog(
      title: const Text('¿Qué dice el sticker?'),
      content: SizedBox(
        width: 420,
        // que entre en la pantalla y deje ver el botón Cancelar
        height: MediaQuery.sizeOf(context).height * 0.5,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar: heladera, baño, cama…',
              ),
              onChanged: (t) => setState(() => _buscar = t),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 120,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: lista.length,
                itemBuilder: (_, i) {
                  final p = lista[i];
                  final foto = widget.store.mediaFile(p.imagePath);
                  final hayFoto = foto != null && File(foto).existsSync();
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.pop(context, p),
                    child: Ink(
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF4FB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: hayFoto
                                ? Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        File(foto),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      p.emoji.isNotEmpty ? p.emoji : '🔤',
                                      style: const TextStyle(fontSize: 40),
                                    ),
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                            child: Text(
                              p.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
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
