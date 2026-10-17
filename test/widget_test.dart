import 'dart:io';

import 'package:alejoapp/board_store.dart';
import 'package:alejoapp/default_boards.dart';
import 'package:alejoapp/main.dart';
import 'package:alejoapp/models.dart';
import 'package:alejoapp/screens/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('alejoapp_test');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('la primera vez crea Inicio y las 6 categorías', () async {
    final store = BoardStore(dir);
    await store.load();
    expect(store.home.items.map((p) => p.label), contains('CASA'));
    expect(store.categories.map((c) => c.name), [
      'NECESIDADES',
      'EMOCIONES',
      'PERSONAS',
      'ACTIVIDADES',
      'LUGARES',
      'RESPUESTAS',
    ]);
  });

  test('los cambios quedan guardados al volver a abrir', () async {
    final store = BoardStore(dir);
    await store.load();
    await store.savePictogram(
      kHomeBoardId,
      Pictogram(id: 'x', label: 'PILETA', emoji: '🏊', audioPath: 'v.m4a'),
    );
    await store.saveCategory(Board(id: 'comidas', name: 'COMIDAS'));
    await store.deleteCategory(store.board('lugares'));

    final again = BoardStore(dir);
    await again.load();
    final picto = again.home.items.last;
    expect(picto.label, 'PILETA');
    expect(picto.audioPath, 'v.m4a');
    expect(again.categories.map((c) => c.id), contains('comidas'));
    expect(again.categories.map((c) => c.id), isNot(contains('lugares')));
  });

  test('borrar un pictograma borra su foto si nadie más la usa', () async {
    final store = BoardStore(dir);
    await store.load();
    final src = File('${dir.path}/foto.jpg')..writeAsStringSync('x');
    final image = await store.importMedia(src, 'jpg');
    final picto = Pictogram(id: 'f', label: 'FOTO', imagePath: image);
    await store.savePictogram(kHomeBoardId, picto);
    expect(File(store.mediaFile(image)!).existsSync(), isTrue);

    await store.deletePictogram(kHomeBoardId, picto);
    expect(File(store.mediaFile(image)!).existsSync(), isFalse);
  });

  test('la palabra se escribe en imprenta mayúscula', () {
    final f = UpperCaseFormatter();
    final out = f.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: 'mamá ñoqui'),
    );
    expect(out.text, 'MAMÁ ÑOQUI');
  });

  // El teléfono puede tener la letra agrandada: los paneles no se tienen que
  // desbordar en pantallas chicas.
  for (final width in [320.0, 360.0, 411.0]) {
    testWidgets('los paneles entran en $width px con letra grande',
        (tester) async {
      tester.view.physicalSize = Size(width * 3, 760 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      late BoardStore store;
      await tester.runAsync(() async {
        store = BoardStore(dir);
        await store.load();
      });
      await tester.pumpWidget(MediaQuery(
        data: MediaQueryData(
          size: Size(width, 760),
          textScaler: const TextScaler.linear(1.6),
        ),
        child: AlejoApp(store: store),
      ));
      await tester.pumpAndSettle();
      expect(find.text('CASA'), findsOneWidget);

      // Modo edición: mantener apretado el candado.
      await tester.longPress(find.byIcon(Icons.lock_outline));
      await tester.pumpAndSettle();
      expect(find.text('Modo edición'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Agregar'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Agregar'), findsOneWidget);

      await tester.tap(find.text('Categorías'));
      await tester.pumpAndSettle();
      expect(find.text('EMOCIONES'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
