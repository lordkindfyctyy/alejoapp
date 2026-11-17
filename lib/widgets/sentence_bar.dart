import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../avisos.dart';
import '../sentence.dart';
import '../speaker.dart';

/// La tira de arriba con la frase que se va armando: los pictogramas tocados
/// en orden, ▶ para decirla entera, ⌫ para sacar el último y ✕ para empezar
/// de nuevo.
class SentenceBar extends StatefulWidget {
  const SentenceBar({super.key});

  static const height = 104.0;

  @override
  State<SentenceBar> createState() => _SentenceBarState();
}

class _SentenceBarState extends State<SentenceBar> {
  final _scroll = ScrollController();
  int _lastCount = 0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Al sumar una palabra, mostrar el final de la tira.
  void _followEnd(int count) {
    if (count <= _lastCount) {
      _lastCount = count;
      return;
    }
    _lastCount = count;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sentence = context.watch<Sentence>();
    final scheme = Theme.of(context).colorScheme;
    final words = sentence.words;
    _followEnd(words.length);

    return Material(
      color: Colors.white,
      elevation: 2,
      child: SizedBox(
        height: SentenceBar.height,
        child: Row(
          children: [
            Expanded(
              child: words.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      // con la letra grande del teléfono se achica en vez de cortarse
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Tocá los dibujos
para armar una frase',
                          style: TextStyle(
                            color: scheme.outline,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: _scroll,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.all(8),
                      itemCount: words.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (_, i) => _WordChip(
                        word: words[i],
                        highlighted: sentence.speaking == i,
                      ),
                    ),
            ),
            _RoundButton(
              icon: Icons.backspace_outlined,
              tooltip: 'Borrar el último',
              onPressed: words.isEmpty ? null : sentence.removeLast,
            ),
            _RoundButton(
              icon: Icons.close,
              tooltip: 'Borrar la frase',
              onPressed: words.isEmpty ? null : sentence.clear,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 10, 0),
              child: SizedBox(
                width: 68,
                height: 68,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2E9D4F),
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: words.isEmpty
                      ? null
                      : () {
                          context.read<Avisos>().decir(
                            sentence.text,
                            esFrase: true,
                          );
                          sentence.speak();
                        },
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 48,
                    semanticLabel: 'Decir la frase',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una palabra en la tira; tocarla la dice sola.
class _WordChip extends StatelessWidget {
  const _WordChip({required this.word, required this.highlighted});

  final SentenceWord word;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final image = word.imageFile;
    return GestureDetector(
      onTap: () => Speaker.instance.say(word.label, audioFile: word.audioFile),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 72,
        decoration: BoxDecoration(
          color: highlighted
              ? const Color(0xFFFFE08A)
              : scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: highlighted
                ? const Color(0xFFE0A800)
                : scheme.outlineVariant,
            width: highlighted ? 3 : 1.5,
          ),
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            Expanded(
              child: image != null && File(image).existsSync()
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(image),
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    )
                  : Center(
                      child: Text(
                        word.emoji.isEmpty ? '💬' : word.emoji,
                        style: const TextStyle(fontSize: 30),
                      ),
                    ),
            ),
            Text(
              word.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    iconSize: 30,
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon),
  );
}
