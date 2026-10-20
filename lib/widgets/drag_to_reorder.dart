import 'package:flutter/material.dart';

/// En modo edición: mantener apretada una tarjeta, arrastrarla y soltarla
/// sobre otra la pone en ese lugar. Un toque sigue abriendo el editor.
class DragToReorder extends StatelessWidget {
  const DragToReorder({
    super.key,
    required this.index,
    required this.onMove,
    required this.child,
  });

  /// Lugar de la tarjeta en el tablero.
  final int index;

  /// Mueve la tarjeta de [from] a [to].
  final void Function(int from, int to) onMove;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, box) => DragTarget<int>(
        onWillAcceptWithDetails: (d) => d.data != index,
        onAcceptWithDetails: (d) => onMove(d.data, index),
        builder: (context, candidates, _) => LongPressDraggable<int>(
          data: index,
          // La tarjeta "levantada" sigue al dedo, del mismo tamaño.
          feedback: SizedBox(
            width: box.maxWidth,
            height: box.maxHeight,
            child: Opacity(opacity: 0.85, child: child),
          ),
          childWhenDragging: Opacity(opacity: 0.25, child: child),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            // Marca dónde va a quedar al soltarla.
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: candidates.isEmpty
                    ? Colors.transparent
                    : scheme.tertiary,
                width: 4,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
