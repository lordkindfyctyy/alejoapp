import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../board_store.dart';
import '../models.dart';
import '../speaker.dart';
import '../widgets/photo_picker.dart';
import '../widgets/picto_tile.dart';
import '../widgets/voice_recorder.dart';

/// Pasa lo que se escribe a imprenta mayúscula (también las tildes: á → Á).
class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
          TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

/// Crea o edita un pictograma ([boardId] + [picto]) o una categoría
/// ([category]). Las categorías no llevan voz grabada.
class EditorScreen extends StatefulWidget {
  const EditorScreen.pictogram({super.key, required this.boardId, this.picto})
      : category = null,
        isCategory = false;

  const EditorScreen.category({super.key, this.category})
      : boardId = null,
        picto = null,
        isCategory = true;

  final String? boardId;
  final Pictogram? picto;
  final Board? category;
  final bool isCategory;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final TextEditingController _label;
  late final TextEditingController _emoji;

  /// Foto/voz guardadas (rutas relativas) y las nuevas elegidas en esta
  /// pantalla (rutas completas a archivos temporales).
  String? _savedImage;
  String? _savedAudio;
  File? _newImage;
  String? _newAudio;
  bool _removeImage = false;
  bool _removeAudio = false;
  bool _saving = false;

  bool get _isNew => widget.isCategory
      ? widget.category == null
      : widget.picto == null;

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(
        text: widget.isCategory ? widget.category?.name : widget.picto?.label);
    _emoji = TextEditingController(
        text: widget.isCategory ? widget.category?.emoji : widget.picto?.emoji);
    _savedImage =
        widget.isCategory ? widget.category?.imagePath : widget.picto?.imagePath;
    _savedAudio = widget.picto?.audioPath;
  }

  @override
  void dispose() {
    _label.dispose();
    _emoji.dispose();
    super.dispose();
  }

  String? _imageToShow(BoardStore store) {
    if (_newImage != null) return _newImage!.path;
    if (_removeImage) return null;
    return store.mediaFile(_savedImage);
  }

  String? _audioToUse(BoardStore store) {
    if (_newAudio != null) return _newAudio;
    if (_removeAudio) return null;
    return store.mediaFile(_savedAudio);
  }

  Future<void> _pickPhoto() async {
    final file = await pickAndCropPhoto(context);
    if (file != null) {
      setState(() {
        _newImage = file;
        _removeImage = false;
      });
    }
  }

  Future<void> _save() async {
    final label = _label.text.trim().toUpperCase();
    if (label.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribí la palabra.')),
      );
      return;
    }
    setState(() => _saving = true);
    final store = context.read<BoardStore>();

    var image = _removeImage ? null : _savedImage;
    if (_newImage != null) image = await store.importMedia(_newImage!, 'jpg');
    var audio = _removeAudio ? null : _savedAudio;
    if (_newAudio != null) audio = await store.importMedia(File(_newAudio!), 'm4a');

    final emoji = _emoji.text.trim();
    if (widget.isCategory) {
      final old = widget.category;
      await store.saveCategory(Board(
        id: old?.id ?? store.newId(),
        name: label,
        emoji: emoji,
        imagePath: image,
        items: old?.items,
      ));
    } else {
      await store.savePictogram(
        widget.boardId!,
        Pictogram(
          id: widget.picto?.id ?? store.newId(),
          label: label,
          emoji: emoji,
          imagePath: image,
          audioPath: audio,
        ),
      );
    }
    // La foto o la voz que se reemplazaron ya no se usan.
    await store.deleteUnusedMedia([
      if (image != _savedImage) _savedImage,
      if (audio != _savedAudio) _savedAudio,
    ]);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final what = widget.isCategory ? 'la categoría' : 'el pictograma';
    final extra = widget.isCategory
        ? '\nTambién se borran todos sus pictogramas.'
        : '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Borrar $what "${_label.text}"?'),
        content: Text('No se puede deshacer.$extra'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final store = context.read<BoardStore>();
    if (widget.isCategory) {
      await store.deleteCategory(widget.category!);
    } else {
      await store.deletePictogram(widget.boardId!, widget.picto!);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<BoardStore>();
    final image = _imageToShow(store);
    final audio = _audioToUse(store);
    final title = widget.isCategory
        ? (_isNew ? 'Nueva categoría' : 'Editar categoría')
        : (_isNew ? 'Nuevo pictograma' : 'Editar pictograma');

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: 'Borrar',
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Vista previa tal como se va a ver en el tablero.
          Center(
            child: SizedBox(
              width: 180,
              height: 220,
              child: ListenableBuilder(
                listenable: Listenable.merge([_label, _emoji]),
                builder: (context, _) => PictoTile(
                  label: _label.text.isEmpty ? 'PALABRA' : _label.text,
                  emoji: _emoji.text,
                  imageFile: image,
                  hasVoice: audio != null,
                  onTap: () => Speaker.instance.say(
                    _label.text,
                    audioFile: widget.isCategory ? null : audio,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tocá la tarjeta para escucharla.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _pickPhoto,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: Text(image == null ? 'Poner foto' : 'Cambiar foto'),
                ),
              ),
              if (image != null) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _newImage = null;
                    _removeImage = true;
                  }),
                  icon: const Icon(Icons.hide_image_outlined),
                  label: const Text('Quitar'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _label,
            inputFormatters: [UpperCaseFormatter()],
            textCapitalization: TextCapitalization.characters,
            maxLength: 30,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            decoration: InputDecoration(
              labelText: widget.isCategory ? 'Nombre' : 'Palabra',
              hintText: widget.isCategory ? 'EMOCIONES' : 'CASA',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _emoji,
            maxLength: 8,
            style: const TextStyle(fontSize: 28),
            decoration: const InputDecoration(
              labelText: 'Emoji (si no tiene foto)',
              hintText: '🏠',
              border: OutlineInputBorder(),
            ),
          ),
          if (!widget.isCategory) ...[
            const SizedBox(height: 12),
            const Text(
              'Voz',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Si grabás tu voz, la tarjeta dice la grabación. Si no, la lee '
              'la voz del teléfono.',
            ),
            const SizedBox(height: 8),
            VoiceRecorder(
              currentFile: audio,
              onChanged: (path) => setState(() {
                _newAudio = path;
                _removeAudio = path == null;
              }),
            ),
          ],
          const SizedBox(height: 28),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
            label: const Text('Guardar', style: TextStyle(fontSize: 20)),
          ),
        ],
      ),
    );
  }
}
