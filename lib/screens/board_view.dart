import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../board_store.dart';
import '../edit_mode.dart';
import '../sentence.dart';
import '../speaker.dart';
import '../widgets/drag_to_reorder.dart';
import '../widgets/picto_tile.dart';
import 'editor_screen.dart';

/// Grilla de pictogramas de un tablero. Tocar uno lo dice en voz alta; en
/// modo edición lo abre para editarlo, se puede arrastrar para cambiarlo de
/// lugar y aparece la tarjeta "+".
class BoardView extends StatelessWidget {
  const BoardView({super.key, required this.boardId});

  final String boardId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<BoardStore>();
    final editing = context.watch<EditMode>().editing;
    final items = store.board(boardId).items;

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: kTileGrid,
      itemCount: items.length + (editing ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == items.length) {
          return AddTile(
            label: 'Agregar',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EditorScreen.pictogram(boardId: boardId),
              ),
            ),
          );
        }
        final picto = items[i];
        final audio = store.mediaFile(picto.audioPath);
        final tile = PictoTile(
          label: picto.label,
          emoji: picto.emoji,
          imageFile: store.mediaFile(picto.imagePath),
          hasVoice: editing && picto.audioPath != null,
          editing: editing,
          onTap: editing
              ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        EditorScreen.pictogram(boardId: boardId, picto: picto),
                  ),
                )
              : () {
                  Speaker.instance.say(picto.label, audioFile: audio);
                  context.read<Sentence>().add(
                    picto,
                    imageFile: store.mediaFile(picto.imagePath),
                    audioFile: audio,
                  );
                },
        );
        if (!editing) return KeyedSubtree(key: ValueKey(picto.id), child: tile);
        return DragToReorder(
          key: ValueKey(picto.id),
          index: i,
          onMove: (from, to) => store.movePictogram(boardId, from, to),
          child: tile,
        );
      },
    );
  }
}
