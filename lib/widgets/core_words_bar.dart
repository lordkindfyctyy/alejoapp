import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../avisos.dart';
import '../models.dart';
import '../sentence.dart';
import '../speaker.dart';

/// Barra fija con las palabras que más se usan para comunicarse (vocabulario núcleo): siempre a mano, sin buscarlas en
/// las categorías. La última llama a papá: lo dice en voz alta y le manda el aviso al celular.
class CoreWordsBar extends StatelessWidget {
  const CoreWordsBar({super.key});

  static const palabras = [
    ('🙏', 'QUIERO'),
    ('➕', 'MÁS'),
    ('✋', 'NO'),
    ('🆘', 'AYUDA'),
    ('✅', 'TERMINÉ'),
  ];

  @override
  Widget build(BuildContext context) {
    final avisos = context.watch<Avisos>();
    Widget boton(
      String emoji,
      String palabra,
      Color color,
      VoidCallback onTap,
    ) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: SizedBox(
              height: 64,
              child: Padding(
                padding: const EdgeInsets.all(4),
                // con letra grande o en teléfonos chicos se achica para entrar
                child: FittedBox(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 22)),
                      Text(
                        palabra,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF16324F),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      child: Row(
        children: [
          for (final (emoji, palabra) in palabras)
            boton(emoji, palabra, const Color(0xFFFFF1C2), () {
              Speaker.instance.say(palabra);
              context.read<Sentence>().add(
                Pictogram(id: 'nucleo-$palabra', label: palabra, emoji: emoji),
              );
              if (palabra == 'AYUDA') {
                avisos.decir('NECESITO AYUDA', urgente: true);
              }
            }),
          boton('📣', '${avisos.cuidador} VENÍ', const Color(0xFFFFD6D6), () {
            final frase = '${avisos.cuidador}, VENÍ';
            Speaker.instance.say(frase);
            avisos.decir(frase, urgente: true);
            final estado = avisos.activo
                ? 'Avisando a ${avisos.cuidador}…'
                : 'Los avisos al celular están apagados (se activan en el modo edición)';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(estado),
                duration: const Duration(seconds: 2),
              ),
            );
          }),
        ],
      ),
    );
  }
}
