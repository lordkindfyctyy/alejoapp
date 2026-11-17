import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../board_store.dart';
import '../edit_mode.dart';
import '../models.dart';
import '../speaker.dart';

/// Agenda visual: "Primero … después …" y la rutina del día con dibujos, para que Alejo sepa qué viene. Cada paso se
/// toca cuando lo termina ("¡Terminé! Ahora …"). En el modo edición se eligen, agregan, ordenan y borran los pasos.
class AgendaView extends StatelessWidget {
  const AgendaView({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<BoardStore>();
    final editing = context.watch<EditMode>().editing;
    final hechos = store.hechosHoy;
    final siguiente = store.rutina.indexWhere((p) => !hechos.contains(p.id));
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const _Titulo('PRIMERO … DESPUÉS'),
        Row(
          children: [
            Expanded(
              child: _Tarjeta(
                etiqueta: 'PRIMERO',
                picto: store.primero,
                store: store,
                color: const Color(0xFFE3F2FD),
                onTap: editing
                    ? () => _elegir(
                        context,
                        (p) => store.elegirPrimeroDespues(primero: p),
                      )
                    : null,
              ),
            ),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 40,
              color: Color(0xFF2E7DD7),
            ),
            Expanded(
              child: _Tarjeta(
                etiqueta: 'DESPUÉS',
                picto: store.despues,
                store: store,
                color: const Color(0xFFE8F5E9),
                onTap: editing
                    ? () => _elegir(
                        context,
                        (p) => store.elegirPrimeroDespues(despues: p),
                      )
                    : null,
              ),
            ),
          ],
        ),
        if (!editing && store.primero != null && store.despues != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: FilledButton.icon(
              onPressed: () => Speaker.instance.say(
                'primero ${store.primero!.label}, después ${store.despues!.label}',
              ),
              icon: const Icon(Icons.volume_up),
              label: const Text('Decir', style: TextStyle(fontSize: 18)),
            ),
          ),
        if (editing)
          const Text(
            'Tocá PRIMERO o DESPUÉS para elegir el pictograma.',
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(child: _Titulo('MI DÍA')),
            if (!editing && hechos.isNotEmpty)
              TextButton.icon(
                onPressed: store.reiniciarDia,
                icon: const Icon(Icons.refresh),
                label: const Text('Empezar de nuevo'),
              ),
          ],
        ),
        for (var i = 0; i < store.rutina.length; i++)
          _Paso(
            picto: store.rutina[i],
            store: store,
            hecho: hechos.contains(store.rutina[i].id),
            ahora: i == siguiente,
            editing: editing,
            onTap: () {
              final p = store.rutina[i];
              final hecho = hechos.contains(p.id);
              if (hecho) {
                store.marcarHecho(p.id, false);
                return;
              }
              store.marcarHecho(p.id, true);
              final resto = store.rutina
                  .skip(i + 1)
                  .where((x) => !hechos.contains(x.id) && x.id != p.id);
              Speaker.instance.say(
                resto.isEmpty
                    ? '¡terminé ${p.label}! ¡terminamos el día!'
                    : '¡terminé ${p.label}! ahora ${resto.first.label}',
              );
            },
            onSubir: i > 0 ? () => store.moverPaso(i, i - 1) : null,
            onBajar: i < store.rutina.length - 1
                ? () => store.moverPaso(i, i + 1)
                : null,
            onBorrar: () => store.borrarPaso(store.rutina[i].id),
          ),
        if (editing)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FilledButton.tonalIcon(
              onPressed: () => _elegir(context, store.agregarPaso),
              icon: const Icon(Icons.add),
              label: const Text(
                'Agregar un paso',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// Elegir un pictograma de los tableros (con su foto y su voz).
  Future<void> _elegir(
    BuildContext context,
    Future<void> Function(Pictogram) usar,
  ) async {
    final store = context.read<BoardStore>();
    final elegido = await showDialog<Pictogram>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elegí un pictograma'),
        content: SizedBox(
          width: 480,
          height: 480,
          child: GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (final p in store.todosLosPictogramas())
                InkWell(
                  onTap: () => Navigator.pop(ctx, p),
                  child: _Imagen(
                    picto: p,
                    store: store,
                    tam: 44,
                    conTexto: true,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    if (elegido != null) await usar(elegido);
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);
  final String texto;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      texto,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w900,
        color: Color(0xFF16324F),
      ),
    ),
  );
}

class _Imagen extends StatelessWidget {
  const _Imagen({
    required this.picto,
    required this.store,
    this.tam = 56,
    this.conTexto = false,
  });
  final Pictogram picto;
  final BoardStore store;
  final double tam;
  final bool conTexto;
  @override
  Widget build(BuildContext context) {
    final f = store.mediaFile(picto.imagePath);
    final img = f != null && File(f).existsSync()
        ? ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              File(f),
              width: tam * 1.6,
              height: tam * 1.6,
              fit: BoxFit.cover,
            ),
          )
        : Text(
            picto.emoji.isEmpty ? '⭐' : picto.emoji,
            style: TextStyle(fontSize: tam),
          );
    if (!conTexto) return img;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        img,
        FittedBox(
          child: Text(
            picto.label,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({
    required this.etiqueta,
    required this.picto,
    required this.store,
    required this.color,
    this.onTap,
  });
  final String etiqueta;
  final Pictogram? picto;
  final BoardStore store;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
    color: color,
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap:
          onTap ??
          (picto == null ? null : () => Speaker.instance.say(picto!.label)),
      child: SizedBox(
        height: 170,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: FittedBox(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  etiqueta,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF16324F),
                  ),
                ),
                const SizedBox(height: 6),
                if (picto != null)
                  _Imagen(picto: picto!, store: store)
                else
                  const Icon(Icons.add_circle_outline, size: 56),
                const SizedBox(height: 4),
                Text(
                  picto?.label ?? 'ELEGIR',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _Paso extends StatelessWidget {
  const _Paso({
    required this.picto,
    required this.store,
    required this.hecho,
    required this.ahora,
    required this.editing,
    required this.onTap,
    this.onSubir,
    this.onBajar,
    required this.onBorrar,
  });
  final Pictogram picto;
  final BoardStore store;
  final bool hecho, ahora, editing;
  final VoidCallback onTap, onBorrar;
  final VoidCallback? onSubir, onBajar;
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: hecho && !editing ? .45 : 1,
    child: Card(
      color: ahora && !editing ? const Color(0xFFFFF3C4) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: ahora && !editing
              ? const Color(0xFFF2B705)
              : Colors.transparent,
          width: 3,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: editing ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              SizedBox(
                width: 92,
                height: 72,
                child: Center(
                  child: _Imagen(picto: picto, store: store, tam: 40),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                // las palabras largas (LEVANTARSE) se achican en vez de cortarse a la mitad
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    picto.label,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              if (!editing && ahora)
                const Text(
                  'AHORA',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFB98900),
                  ),
                ),
              if (!editing && hecho)
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF2E9D4F),
                  size: 40,
                ),
              if (editing) ...[
                IconButton(
                  onPressed: onSubir,
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  onPressed: onBajar,
                  icon: const Icon(Icons.arrow_downward),
                ),
                IconButton(
                  onPressed: onBorrar,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
