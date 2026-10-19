import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../board_store.dart';
import '../edit_mode.dart';
import '../models.dart';
import '../speaker.dart';
import '../widgets/picto_tile.dart';
import '../widgets/sentence_bar.dart';
import 'board_view.dart';
import 'editor_screen.dart';

/// Panel de categorías: Necesidades, Emociones, Personas, Actividades,
/// Lugares, Respuestas y las que se agreguen.
class CategoriesView extends StatelessWidget {
  const CategoriesView({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<BoardStore>();
    final editing = context.watch<EditMode>().editing;
    final categories = store.categories;

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: kTileGrid,
      itemCount: categories.length + (editing ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == categories.length) {
          return AddTile(
            label: 'Nueva categoría',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditorScreen.category()),
            ),
          );
        }
        final category = categories[i];
        return PictoTile(
          key: ValueKey(category.id),
          label: category.name,
          emoji: category.emoji,
          imageFile: store.mediaFile(category.imagePath),
          editing: editing,
          color: Theme.of(context).colorScheme.secondaryContainer,
          onTap: editing
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditorScreen.category(category: category),
                    ),
                  )
              : () => _open(context, category),
        );
      },
    );
  }

  void _open(BuildContext context, Board category) {
    Speaker.instance.say(category.name);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CategoryScreen(categoryId: category.id)),
    );
  }
}

/// Los pictogramas de una categoría.
class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<BoardStore>();
    // Si se borró la categoría desde el modo edición, volver.
    if (!store.categories.any((c) => c.id == categoryId)) {
      return const Scaffold();
    }
    final category = store.board(categoryId);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: Text(
          '${category.emoji} ${category.name}'.trim(),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        actions: [EditModeButton(mode: context.read<EditMode>())],
      ),
      body: Column(
        children: [
          const SentenceBar(),
          Expanded(child: BoardView(boardId: categoryId)),
        ],
      ),
    );
  }
}
