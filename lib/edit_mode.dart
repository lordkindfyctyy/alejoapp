import 'package:flutter/material.dart';

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
              ..showSnackBar(const SnackBar(
                content: Text('Para editar, mantené apretado el candado.'),
              ));
          },
        );
      },
    );
  }
}
