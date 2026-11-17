import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../avisos.dart';
import '../board_store.dart';
import '../speaker.dart';
import '../widgets/picto_tile.dart';

/// "Me siento": cómo se siente (con cuánto) y dónde le duele (tocando un cuerpito). Lo dice en voz alta y, si los avisos
/// están activos, el dolor le llega a papá al celular.
class FeelingsView extends StatefulWidget {
  const FeelingsView({super.key});

  @override
  State<FeelingsView> createState() => _FeelingsViewState();
}

/// Parte del cuerpo: id, cómo se dice ("la panza") y dónde va en el dibujo (fracciones del ancho y alto).
class _Parte {
  const _Parte(
    this.id,
    this.dicho,
    this.x,
    this.y,
    this.ancho,
    this.alto, {
    this.redonda = false,
  });
  final String id, dicho;
  final double x, y, ancho, alto;
  final bool redonda;
}

const _partes = [
  _Parte('cabeza', 'la cabeza', .34, .00, .32, .17, redonda: true),
  _Parte('garganta', 'la garganta', .43, .17, .14, .05),
  _Parte('pecho', 'el pecho', .30, .22, .40, .14),
  _Parte('panza', 'la panza', .30, .36, .40, .14),
  _Parte('brazo_i', 'el brazo', .12, .22, .16, .26),
  _Parte('brazo_d', 'el brazo', .72, .22, .16, .26),
  _Parte('mano_i', 'la mano', .08, .48, .14, .08, redonda: true),
  _Parte('mano_d', 'la mano', .78, .48, .14, .08, redonda: true),
  _Parte('pierna_i', 'la pierna', .31, .51, .17, .36),
  _Parte('pierna_d', 'la pierna', .52, .51, .17, .36),
  _Parte('pie_i', 'el pie', .25, .88, .22, .07, redonda: true),
  _Parte('pie_d', 'el pie', .53, .88, .22, .07, redonda: true),
];

const _extras = [
  ('👀', 'los ojos'),
  ('👂', 'el oído'),
  ('🦷', 'los dientes'),
  ('🔙', 'la espalda'),
  ('🤢', 'la panza, tengo ganas de vomitar'),
];

class _FeelingsViewState extends State<FeelingsView> {
  String? _emocion; // palabra elegida (FELIZ, TRISTE...)
  String? _dolor; // cómo se dice la parte ("la panza")
  String? _ultima;

  void _decir(String frase, {bool urgente = false}) {
    setState(() => _ultima = frase.toUpperCase());
    Speaker.instance.say(frase);
    context.read<Avisos>().decir(frase.toUpperCase(), urgente: urgente);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<BoardStore>();
    final avisos = context.watch<Avisos>();
    final emociones = store.categories
        .where((b) => b.id == 'emociones')
        .expand((b) => b.items)
        .toList();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_ultima != null)
          Card(
            color: const Color(0xFFE3F2FD),
            child: ListTile(
              leading: const Icon(Icons.record_voice_over, size: 36),
              title: Text(
                _ultima!,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              subtitle: avisos.activo && avisos.ultimoEstado != null
                  ? Text(avisos.ultimoEstado!)
                  : null,
              trailing: IconButton(
                icon: const Icon(Icons.replay, size: 32),
                onPressed: () => Speaker.instance.say(_ultima!.toLowerCase()),
              ),
            ),
          ),
        const _Titulo('¿CÓMO TE SENTÍS?'),
        GridView.count(
          crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (final p in emociones)
              PictoTile(
                label: p.label,
                emoji: p.emoji,
                imageFile: store.mediaFile(p.imagePath),
                hasVoice: false,
                editing: false,
                onTap: () {
                  setState(() => _emocion = p.label);
                  Speaker.instance.say(p.label);
                },
              ),
          ],
        ),
        if (_emocion != null) ...[
          const SizedBox(height: 8),
          Text(
            '¿CUÁNTO ${_emocion!}?',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final (marcas, como, frase) in [
                ('▮', 'UN POCO', 'estoy un poco ${_emocion!.toLowerCase()}'),
                ('▮▮', 'BASTANTE', 'estoy ${_emocion!.toLowerCase()}'),
                ('▮▮▮', 'MUCHO', 'estoy muy ${_emocion!.toLowerCase()}'),
              ])
                Expanded(child: _Grande(marcas, como, () => _decir(frase))),
            ],
          ),
        ],
        const SizedBox(height: 16),
        const _Titulo('¿TE DUELE ALGO? TOCÁ DÓNDE'),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: AspectRatio(
              aspectRatio: .62,
              child: LayoutBuilder(
                builder: (context, c) {
                  return Stack(
                    children: [
                      for (final p in _partes)
                        Positioned(
                          left: p.x * c.maxWidth,
                          top: p.y * c.maxHeight,
                          width: p.ancho * c.maxWidth,
                          height: p.alto * c.maxHeight,
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _dolor = p.dicho);
                              Speaker.instance.say(
                                p.dicho.replaceFirst(
                                  RegExp(r'^(la|el|los) '),
                                  '',
                                ),
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: _dolor == p.dicho
                                    ? const Color(0xFFFF6B6B)
                                    : const Color(0xFFFFE0C2),
                                border: Border.all(
                                  color: const Color(0xFFB07A52),
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(
                                  p.redonda ? 999 : 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (emoji, dicho) in _extras)
              ChoiceChip(
                label: Text(
                  '$emoji ${dicho.split(',').first.replaceFirst(RegExp(r'^(la|el|los) '), '').toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                selected: _dolor == dicho,
                onSelected: (_) => setState(() => _dolor = dicho),
              ),
          ],
        ),
        if (_dolor != null) ...[
          const SizedBox(height: 10),
          Text(
            'ME DUELE ${_dolor!.split(',').first.replaceFirst(RegExp(r'^(la|el|los) '), '').toUpperCase()}… ¿CUÁNTO?',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _Grande(
                  '🙂',
                  'UN POCO',
                  () => _decir('me duele un poco ${_dolor!}', urgente: true),
                ),
              ),
              Expanded(
                child: _Grande(
                  '😣',
                  'MUCHO',
                  () => _decir('me duele mucho ${_dolor!}', urgente: true),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
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

class _Grande extends StatelessWidget {
  const _Grande(this.arriba, this.texto, this.onTap);
  final String arriba, texto;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(4),
    child: Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          height: 86,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                arriba,
                style: const TextStyle(fontSize: 26, color: Color(0xFFE53935)),
              ),
              Text(
                texto,
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
  );
}
