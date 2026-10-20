import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../board_store.dart';
import '../edit_mode.dart';
import '../screens/editor_screen.dart' show UpperCaseFormatter;
import '../sentence.dart';
import '../talking.dart';
import '../widgets/photo_picker.dart';
import '../widgets/talking_face.dart';
import '../widgets/voice_recorder.dart';

/// "Yo hablo": la foto del chico ocupa la pantalla y, al tocar una frase,
/// la dice moviendo la boca, para que se vea a sí mismo hablando.
class TalkingView extends StatefulWidget {
  const TalkingView({super.key, this.controller});

  /// Los tests pasan uno que no usa la voz del teléfono.
  final TalkingController? controller;

  @override
  State<TalkingView> createState() => _TalkingViewState();
}

class _TalkingViewState extends State<TalkingView> {
  late final TalkingController _talk = widget.controller ?? TalkingController();

  @override
  void dispose() {
    if (widget.controller == null) _talk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      TalkingStage(controller: _talk, fullScreen: false);
}

/// La foto, la frase que se está diciendo y los botones de las frases. Se
/// usa en la pestaña y a pantalla completa.
class TalkingStage extends StatelessWidget {
  const TalkingStage({
    super.key,
    required this.controller,
    required this.fullScreen,
  });

  final TalkingController controller;
  final bool fullScreen;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<BoardStore>();
    final editing = context.watch<EditMode>().editing && !fullScreen;
    final talking = store.talking;
    final photo = store.mediaFile(talking.imagePath);
    final hasPhoto = photo != null && File(photo).existsSync();

    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasPhoto)
                GestureDetector(
                  // Tocar la foto repite la última frase.
                  onTap: () => _sayLast(context, controller),
                  child: TalkingFace(
                    file: photo,
                    photo: talking,
                    controller: controller,
                  ),
                )
              else
                _NoPhoto(editing: editing),
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  children: [
                    if (editing) ...[
                      _RoundButton(
                        icon: Icons.add_a_photo,
                        tooltip: hasPhoto
                            ? 'Cambiar la foto'
                            : 'Elegir la foto',
                        onPressed: () => _pickPhoto(context),
                      ),
                      if (hasPhoto)
                        _RoundButton(
                          icon: Icons.face_retouching_natural,
                          tooltip: 'Marcar la boca',
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MouthEditor(),
                            ),
                          ),
                        ),
                    ],
                    if (hasPhoto && !editing)
                      _RoundButton(
                        icon: fullScreen
                            ? Icons.fullscreen_exit
                            : Icons.fullscreen,
                        tooltip: fullScreen ? 'Salir' : 'Pantalla completa',
                        onPressed: () => fullScreen
                            ? Navigator.pop(context)
                            : _openFullScreen(context, controller),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _Subtitle(controller: controller),
        _PhraseStrip(controller: controller, editing: editing),
      ],
    );
  }

  static Future<void> _pickPhoto(BuildContext context) async {
    final store = context.read<BoardStore>();
    final file = await pickAndCropPhoto(context, square: false);
    if (file == null) return;
    final path = await store.importMedia(file, 'jpg');
    await store.saveTalkingPhoto(imagePath: path);
    if (context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MouthEditor()),
      );
    }
  }

  static Future<void> _openFullScreen(
    BuildContext context,
    TalkingController controller,
  ) async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: TalkingStage(controller: controller, fullScreen: true),
          ),
        ),
      ),
    );
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
}

String? _lastText;
String? _lastAudio;

void _say(TalkingController controller, String text, String? audio) {
  _lastText = text;
  _lastAudio = audio;
  controller.say(text, audioFile: audio);
}

void _sayLast(BuildContext context, TalkingController controller) {
  final text = _lastText;
  if (text != null) {
    controller.say(text, audioFile: _lastAudio);
    return;
  }
  final phrases = context.read<BoardStore>().talking.phrases;
  if (phrases.isNotEmpty) {
    final store = context.read<BoardStore>();
    _say(
      controller,
      phrases.first.text,
      store.mediaFile(phrases.first.audioPath),
    );
  }
}

class _NoPhoto extends StatelessWidget {
  const _NoPhoto({required this.editing});

  final bool editing;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8F0FA),
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      // Con letra grande en un teléfono chico no entra: se desliza.
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🙂',
              textScaler: TextScaler.noScaling,
              style: TextStyle(fontSize: 72),
            ),
            const SizedBox(height: 12),
            Text(
              editing
                  ? 'Tocá la cámara de arriba para poner una foto de frente, '
                        'con la boca cerrada y bien iluminada.'
                  : 'Acá va a estar tu foto hablando. Un adulto la pone desde el '
                        'modo edición (mantener apretado el candado).',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: IconButton.filled(
        style: IconButton.styleFrom(
          backgroundColor: Colors.black54,
          foregroundColor: Colors.white,
        ),
        iconSize: 30,
        icon: Icon(icon),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}

/// La frase que está diciendo, con la palabra de ahora resaltada.
class _Subtitle extends StatelessWidget {
  const _Subtitle({required this.controller});

  final TalkingController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final words = controller.words;
        final current = controller.speaking ? controller.word : null;
        return Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          constraints: const BoxConstraints(minHeight: 52),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              for (final (i, w) in words.indexed)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: i == current ? const Color(0xFFFFD54F) : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    w,
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Los botones de las frases. En modo edición se tocan para cambiarlas y
/// aparece "+ FRASE".
class _PhraseStrip extends StatelessWidget {
  const _PhraseStrip({required this.controller, required this.editing});

  final TalkingController controller;
  final bool editing;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<BoardStore>();
    final sentence = context.watch<Sentence>();
    final scheme = Theme.of(context).colorScheme;
    final phrases = store.talking.phrases;
    return Container(
      color: scheme.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // La frase armada con los pictogramas también la puede decir.
            if (!editing && !sentence.isEmpty)
              _PhraseButton(
                text: '▶ ${sentence.text}',
                color: scheme.tertiaryContainer,
                onTap: () => _say(controller, sentence.text, null),
              ),
            for (final p in phrases)
              _PhraseButton(
                text: p.text,
                hasVoice: p.audioPath != null,
                editing: editing,
                onTap: editing
                    ? () => _editPhrase(context, p)
                    : () => _say(
                        controller,
                        p.text,
                        store.mediaFile(p.audioPath),
                      ),
              ),
            if (editing)
              _PhraseButton(
                text: '+ FRASE',
                color: scheme.primaryContainer,
                onTap: () => _editPhrase(context, null),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhraseButton extends StatelessWidget {
  const _PhraseButton({
    required this.text,
    required this.onTap,
    this.color,
    this.hasVoice = false,
    this.editing = false,
  });

  final String text;
  final VoidCallback onTap;
  final Color? color;
  final bool hasVoice;
  final bool editing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: color ?? scheme.surfaceContainerLowest,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: editing ? scheme.primary : scheme.outlineVariant,
            width: editing ? 3 : 1.5,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 64, minWidth: 96),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasVoice) ...[
                  Icon(Icons.mic, size: 18, color: scheme.primary),
                  const SizedBox(width: 4),
                ],
                if (editing) ...[
                  Icon(Icons.edit, size: 18, color: scheme.primary),
                  const SizedBox(width: 4),
                ],
                Text(
                  text,
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _editPhrase(BuildContext context, Phrase? phrase) =>
    showDialog<void>(
      context: context,
      builder: (_) => _PhraseDialog(phrase: phrase),
    );

class _PhraseDialog extends StatefulWidget {
  const _PhraseDialog({this.phrase});

  final Phrase? phrase;

  @override
  State<_PhraseDialog> createState() => _PhraseDialogState();
}

class _PhraseDialogState extends State<_PhraseDialog> {
  late final _text = TextEditingController(text: widget.phrase?.text ?? '');
  String? _newAudio;
  bool _removeAudio = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _text.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.isEmpty) {
      setState(() => _error = 'Escribí lo que va a decir');
      return;
    }
    final store = context.read<BoardStore>();
    var audio = _removeAudio ? null : widget.phrase?.audioPath;
    if (_newAudio != null) {
      audio = await store.importMedia(File(_newAudio!), 'm4a');
    }
    await store.savePhrase(
      Phrase(
        id: widget.phrase?.id ?? store.newId(),
        text: text,
        audioPath: audio,
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final phrase = widget.phrase!;
    final store = context.read<BoardStore>();
    final navigator = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Borrar la frase "${phrase.text}"?'),
        content: const Text('Se borra también su grabación.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await store.deletePhrase(phrase);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<BoardStore>();
    final current =
        _newAudio ??
        (_removeAudio ? null : store.mediaFile(widget.phrase?.audioPath));
    return AlertDialog(
      title: Text(widget.phrase == null ? 'Nueva frase' : 'Cambiar la frase'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _text,
              autofocus: widget.phrase == null,
              inputFormatters: [UpperCaseFormatter()],
              textCapitalization: TextCapitalization.characters,
              maxLength: 60,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              decoration: InputDecoration(
                labelText: 'Lo que dice',
                hintText: 'YO QUIERO JUGAR',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Si grabás tu voz, la foto habla con tu voz. Si no, usa la del '
              'teléfono.',
            ),
            const SizedBox(height: 8),
            VoiceRecorder(
              currentFile: current,
              onChanged: (path) => setState(() {
                _newAudio = path;
                _removeAudio = path == null;
              }),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.phrase != null)
          TextButton(onPressed: _delete, child: const Text('Borrar')),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}

/// Marcar dónde está la boca: se arrastra la marca celeste hasta el medio de
/// los labios y se ajusta el ancho. "Probar" la hace hablar.
class MouthEditor extends StatefulWidget {
  const MouthEditor({super.key, this.controller});

  final TalkingController? controller;

  @override
  State<MouthEditor> createState() => _MouthEditorState();
}

class _MouthEditorState extends State<MouthEditor> {
  late final TalkingController _talk = widget.controller ?? TalkingController();
  late TalkingPhoto _draft;

  @override
  void initState() {
    super.initState();
    final t = context.read<BoardStore>().talking;
    _draft = TalkingPhoto(
      imagePath: t.imagePath,
      mouthX: t.mouthX,
      mouthY: t.mouthY,
      mouthWidth: t.mouthWidth,
    );
  }

  @override
  void dispose() {
    if (widget.controller == null) _talk.dispose();
    super.dispose();
  }

  void _move(Offset photoPoint) {
    setState(() {
      _draft = TalkingPhoto(
        imagePath: _draft.imagePath,
        mouthX: photoPoint.dx.clamp(0.0, 1.0),
        mouthY: photoPoint.dy.clamp(0.0, 1.0),
        mouthWidth: _draft.mouthWidth,
      );
    });
  }

  Future<void> _save() async {
    await context.read<BoardStore>().saveTalkingPhoto(
      mouthX: _draft.mouthX,
      mouthY: _draft.mouthY,
      mouthWidth: _draft.mouthWidth,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<BoardStore>();
    final file = store.mediaFile(_draft.imagePath);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marcar la boca'),
        actions: [
          TextButton(
            onPressed: _save,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Guardar', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Tocá o arrastrá la marca celeste hasta el medio de los labios, '
              'y ajustá el ancho para que tome toda la boca.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: file == null
                ? const SizedBox.shrink()
                : PhotoLoader(
                    file: file,
                    builder: (context, image) => LayoutBuilder(
                      builder: (context, box) {
                        final layout = PhotoLayout(
                          Size(image.width.toDouble(), image.height.toDouble()),
                          box.biggest,
                        );
                        return GestureDetector(
                          onTapDown: (d) =>
                              _move(layout.toPhoto(d.localPosition)),
                          onPanUpdate: (d) =>
                              _move(layout.toPhoto(d.localPosition)),
                          child: ListenableBuilder(
                            listenable: _talk,
                            builder: (context, _) => _AnimatedFace(
                              controller: _talk,
                              image: image,
                              photo: _draft,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                const Text('Ancho', style: TextStyle(fontSize: 16)),
                Expanded(
                  child: Slider(
                    value: _draft.mouthWidth,
                    min: 0.05,
                    max: 0.6,
                    onChanged: (v) => setState(() {
                      _draft = TalkingPhoto(
                        imagePath: _draft.imagePath,
                        mouthX: _draft.mouthX,
                        mouthY: _draft.mouthY,
                        mouthWidth: v,
                      );
                    }),
                  ),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Probar'),
                  onPressed: () => _talk.say('HOLA MAMÁ'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// La cara del editor: se mueve al probar y muestra la marca.
class _AnimatedFace extends StatefulWidget {
  const _AnimatedFace({
    required this.controller,
    required this.image,
    required this.photo,
  });

  final TalkingController controller;
  final ui.Image image;
  final TalkingPhoto photo;

  @override
  State<_AnimatedFace> createState() => _AnimatedFaceState();
}

class _AnimatedFaceState extends State<_AnimatedFace>
    with SingleTickerProviderStateMixin {
  late final AnimationController _frames = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  @override
  void dispose() {
    _frames.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.speaking) {
      if (!_frames.isAnimating) _frames.repeat();
    } else {
      _frames.stop();
    }
    return AnimatedBuilder(
      animation: _frames,
      builder: (context, _) => CustomPaint(
        size: Size.infinite,
        painter: FacePainter(
          image: widget.image,
          photo: widget.photo,
          opening: widget.controller.opening,
          showMark: !widget.controller.speaking,
        ),
      ),
    );
  }
}
