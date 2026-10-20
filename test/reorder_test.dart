import 'dart:io';

import 'package:alejoapp/board_store.dart';
import 'package:alejoapp/default_boards.dart';
import 'package:alejoapp/edit_mode.dart';
import 'package:alejoapp/screens/board_view.dart';
import 'package:alejoapp/sentence.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('alejoapp_reorder');
  });

  tearDown(() async {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } on FileSystemException {
      // Windows a veces todavía tiene abierto el último guardado; es una
      // carpeta temporal.
    }
  });

  test('el nuevo orden queda guardado', () async {
    final store = BoardStore(dir);
    await store.load();
    final labels = store.home.items.map((p) => p.label).toList();
    await store.movePictogram(kHomeBoardId, 2, 0);
    final cats = store.categories.map((c) => c.id).toList();
    await store.moveCategory(0, cats.length - 1);

    final again = BoardStore(dir);
    await again.load();
    expect(again.home.items.first.label, labels[2]);
    expect(again.home.items.length, labels.length);
    expect(again.categories.last.id, cats.first);
    expect(again.categories.length, cats.length);
  });

  Future<BoardStore> pumpBoard(
    WidgetTester tester, {
    required bool editing,
  }) async {
    tester.view.physicalSize = const Size(360 * 3, 760 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    late BoardStore store;
    await tester.runAsync(() async {
      store = BoardStore(dir);
      await store.load();
    });
    final mode = EditMode();
    if (editing) mode.toggle();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: store),
          ChangeNotifierProvider.value(value: mode),
          ChangeNotifierProvider(
            create: (_) =>
                Sentence(say: (_, {audioFile, wait = false}) async {}),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: BoardView(boardId: kHomeBoardId)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return store;
  }

  Future<void> drag(WidgetTester tester, String from, String to) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.text(from)),
    );
    await tester.pump(const Duration(seconds: 1));
    await gesture.moveTo(tester.getCenter(find.text(to)));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('en modo edición se arrastra un dibujo a otro lugar', (
    tester,
  ) async {
    final store = await pumpBoard(tester, editing: true);
    final first = store.home.items[0].label;
    final third = store.home.items[2].label;

    await drag(tester, third, first);
    // Deja terminar el guardado en el disco.
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();

    expect(store.home.items[0].label, third);
    expect(store.home.items[1].label, first);
  });

  testWidgets('sin modo edición no se mueve nada', (tester) async {
    final store = await pumpBoard(tester, editing: false);
    final before = store.home.items.map((p) => p.label).toList();
    await drag(tester, before[2], before[0]);
    expect(store.home.items.map((p) => p.label).toList(), before);
  });
}
