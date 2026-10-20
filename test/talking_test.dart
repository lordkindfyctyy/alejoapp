import 'dart:io';

import 'package:alejoapp/board_store.dart';
import 'package:alejoapp/default_boards.dart';
import 'package:alejoapp/edit_mode.dart';
import 'package:alejoapp/models.dart';
import 'package:alejoapp/screens/talking_view.dart';
import 'package:alejoapp/sentence.dart';
import 'package:alejoapp/talking.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('alejoapp_talking');
  });

  tearDown(() async {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } on FileSystemException {
      // Carpeta temporal que Windows todavía tiene abierta.
    }
  });

  test('la boca se abre más con la "a" que con la "i"', () {
    expect(syllableOpenings('HOLA'), [0.8, 1.0]);
    expect(syllableOpenings('AGUA'), [1.0, 1.0]);
    expect(syllableOpenings('MI'), [0.55]);
    expect(syllableOpenings('TV'), [0.7]);
  });

  test('cada sílaba abre y cierra la boca', () {
    final pulses = estimatePulses(['HOLA', 'MAMÁ']);
    expect(pulses.length, 4);
    expect(pulses.map((p) => p.word), [0, 0, 1, 1]);
    final first = pulses.first;
    expect(mouthOpening(pulses, first.start), closeTo(0, 0.01));
    expect(
      mouthOpening(pulses, first.start + first.length ~/ 2),
      closeTo(0.8, 0.01),
    );
    expect(wordAt(pulses, pulses[2].start), 1);
    expect(mouthOpening(pulses, pulses.last.end + kSyllable), 0);
  });

  test('la posición que avisa la voz es la palabra correcta', () {
    const text = 'yo quiero agua';
    expect(wordIndexAt(text, 0), 0);
    expect(wordIndexAt(text, 3), 1);
    expect(wordIndexAt(text, 10), 2);
  });

  test('mientras habla sigue las palabras que avisa la voz', () async {
    final seen = <int?>[];
    late TalkingController talk;
    talk = TalkingController(
      talk: (text, {audioFile, onWord}) async {
        onWord!(0, 2);
        seen.add(talk.word);
        expect(talk.speaking, isTrue);
        expect(talk.words, ['YO', 'QUIERO']);
        onWord(3, 9);
      },
      audioLength: (_) async => null,
    );
    await talk.say('YO QUIERO');
    expect(seen, [0]);
    expect(talk.speaking, isFalse);
    expect(talk.opening, 0);
  });

  test('con la voz grabada reparte las sílabas en la grabación', () async {
    final talk = TalkingController(
      talk: (text, {audioFile, onWord}) async {
        expect(audioFile, 'voz.m4a');
      },
      audioLength: (_) async => const Duration(seconds: 2),
    );
    await talk.say('HOLA', audioFile: 'voz.m4a');
    expect(talk.speaking, isFalse);
  });

  test('la foto y las frases quedan guardadas', () async {
    final store = BoardStore(dir);
    await store.load();
    expect(store.talking.phrases.map((p) => p.text), contains('HOLA'));

    final src = File('${dir.path}/alejo.jpg')..writeAsStringSync('x');
    final image = await store.importMedia(src, 'jpg');
    await store.saveTalkingPhoto(imagePath: image, mouthX: 0.4, mouthY: 0.7);
    await store.savePhrase(Phrase(id: 'n', text: 'VAMOS A LA PLAZA'));
    // Borrar un pictograma no borra la foto de "Yo hablo".
    final picto = Pictogram(id: 'p', label: 'X', imagePath: image);
    await store.savePictogram(kHomeBoardId, picto);
    await store.deletePictogram(kHomeBoardId, picto);

    final again = BoardStore(dir);
    await again.load();
    expect(again.talking.imagePath, image);
    expect(again.talking.mouthX, 0.4);
    expect(again.talking.mouthY, 0.7);
    expect(again.talking.phrases.last.text, 'VAMOS A LA PLAZA');
    expect(File(again.mediaFile(image)!).existsSync(), isTrue);

    await again.deletePhrase(again.talking.phrases.last);
    expect(
      again.talking.phrases.map((p) => p.text),
      isNot(contains('VAMOS A LA PLAZA')),
    );
  });

  for (final width in [320.0, 411.0]) {
    testWidgets('"Yo hablo" sin foto entra en $width px con letra grande', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width * 3, 700 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      late BoardStore store;
      await tester.runAsync(() async {
        store = BoardStore(dir);
        await store.load();
      });
      final said = <String>[];
      final talk = TalkingController(
        talk: (text, {audioFile, onWord}) async => said.add(text),
        audioLength: (_) async => null,
      );
      addTearDown(talk.dispose);
      for (final editing in [false, true]) {
        final mode = EditMode();
        if (editing) mode.toggle();
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: Size(width, 700),
              textScaler: const TextScaler.linear(1.6),
            ),
            child: MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: store),
                ChangeNotifierProvider.value(value: mode),
                ChangeNotifierProvider(
                  create: (_) =>
                      Sentence(say: (_, {audioFile, wait = false}) async {}),
                ),
              ],
              child: MaterialApp(
                home: Scaffold(body: TalkingView(controller: talk)),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('🙂'), findsOneWidget);
        expect(find.text('HOLA'), findsOneWidget);
        expect(find.text('+ FRASE'), editing ? findsOneWidget : findsNothing);
        expect(tester.takeException(), isNull);
      }

      // Fuera del modo edición, tocar una frase la dice.
      final mode = EditMode();
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
          child: MaterialApp(
            home: Scaffold(body: TalkingView(controller: talk)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('HOLA'));
      await tester.pump(const Duration(seconds: 2));
      expect(said, ['HOLA']);
    });
  }
}
