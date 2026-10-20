import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Modo edición: cuando está apagado, los botones solo hablan, así el chico
/// no puede borrar ni cambiar nada sin querer.
class EditMode extends ChangeNotifier {
  bool _editing = false;

  bool get editing => _editing;

  void toggle() {
    _editing = !_editing;
    notifyListeners();
  }
}

/// Cartel arriba del tablero en modo edición: cómo cambiar y mover los
/// dibujos. Fuera del modo edición no ocupa lugar.
class EditHint extends StatelessWidget {
  const EditHint({super.key});

  @override
  Widget build(BuildContext context) {
    if (!context.watch<EditMode>().editing) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFE6C7),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        'Tocá un dibujo para cambiarlo. Para moverlo de lugar, mantenelo '
        'apretado y arrastralo.',
        style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Candado de la barra de arriba. Para entrar al modo edición hay que
/// mantenerlo apretado (un toque solo muestra cómo hacerlo).
class EditModeButton extends StatelessWidget {
  const EditModeButton({super.key, required this.mode});

  final EditMode mode;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: mode,
      builder: (context, _) {
        if (mode.editing) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
              onPressed: mode.toggle,
              icon: const Icon(Icons.lock_open),
              label: const Text('Listo'),
            ),
          );
        }
        return IconButton(
          icon: const Icon(Icons.lock_outline),
          onLongPress: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            mode.toggle();
          },
          onPressed: () {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  content: Text('Para editar, mantené apretado el candado.'),
                ),
              );
          },
        );
      },
    );
  }
}
