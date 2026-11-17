import 'dart:io';

import 'package:alejoapp/board_store.dart';
import 'package:alejoapp/main.dart';
import 'package:alejoapp/models.dart';
import 'package:alejoapp/sentence.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lo que se "dijo" en voz alta, en orden.
class FakeVoice {
  final said = <String>[];

  Future<void> say(String text, {String? audioFile, bool wait = false}) async {
    said.add(audioFile == null ? text : '$text(grabación)');
  }
}

Pictogram picto(String label, [String? audio]) =>
    Pictogram(id: label, label: label, emoji: '🙂', audioPath: audio);

void main() {
  test('se arma, se borra el último y se limpia', () {
    final s = Sentence(say: FakeVoice().say);
    s.add(picto('YO'));
    s.add(picto('QUIERO'));
    s.add(picto('AGUA'));
    expect(s.text, 'YO QUIERO AGUA');
    s.removeLast();
    expect(s.text, 'YO QUIERO');
    s.clear();
    expect(s.isEmpty, isTrue);
    s.removeLast(); // vacía: no pasa nada
    expect(s.isEmpty, isTrue);
  });

  test('no pasa de 12 palabras', () {
    final s = Sentence(say: FakeVoice().say);
    for (var i = 0; i < 20; i++) {
      s.add(picto('P$i'));
    }
    expect(s.words.length, Sentence.maxWords);
  });

  test(
    'sin grabaciones la dice de una vez; con grabaciones, palabra por palabra',
    () async {
      final voice = FakeVoice();
      final s = Sentence(say: voice.say);
      s.add(picto('YO'));
      s.add(picto('QUIERO'));
      await s.speak();
      expect(voice.said, ['YO QUIERO']);

      voice.said.clear();
      s.add(picto('MAMÁ'), audioFile: '/voz/mama.m4a');
      final highlighted = <int?>[];
      s.addListener(() => highlighted.add(s.speaking));
      await s.speak();
      expect(voice.said, ['YO', 'QUIERO', 'MAMÁ(grabación)']);
      expect(highlighted, [0, 1, 2, null]);
    },
  );

  testWidgets('tocar pictogramas los suma a la tira y ▶ dice la frase', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360 * 3, 760 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    late Directory dir;
    late BoardStore store;
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('alejoapp_sentence');
      store = BoardStore(dir);
      await store.load();
    });
    addTearDown(() => dir.deleteSync(recursive: true));
    final voice = FakeVoice();

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 760),
          textScaler: TextScaler.linear(1.6),
        ),
        child: AlejoApp(
          store: store,
          sentence: Sentence(say: voice.say),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tocá los dibujos para armar una frase'), findsOneWidget);

    final first = store.home.items[0].label;
    final second = store.home.items[1].label;
    await tester.tap(find.text(first));
    await tester.tap(find.text(second));
    await tester.pumpAndSettle();
    // Cada palabra aparece en el tablero y en la tira.
    expect(find.text(first), findsNWidgets(2));
    expect(find.text(second), findsNWidgets(2));

    await tester.tap(find.bySemanticsLabel('Decir la frase'));
    await tester.pumpAndSettle();
    expect(voice.said, ['$first $second']);

    await tester.tap(find.byTooltip('Borrar el último'));
    await tester.pumpAndSettle();
    expect(find.text(second), findsOneWidget);

    await tester.tap(find.byTooltip('Borrar la frase'));
    await tester.pumpAndSettle();
    expect(find.text('Tocá los dibujos para armar una frase'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
