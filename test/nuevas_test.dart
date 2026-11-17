import 'dart:io';

import 'package:alejoapp/avisos.dart';
import 'package:alejoapp/board_store.dart';
import 'package:alejoapp/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  setUp(
    () async => dir = await Directory.systemTemp.createTemp('alejo_nuevas'),
  );
  tearDown(() async => dir.delete(recursive: true));

  test('avisos: anota todo y solo manda al celular si están activos (y las frases si se pidió)', () async {
    final enviados = <Map<String, dynamic>>[];
    final avisos = Avisos(
      dir,
      enviarHttp: (d) async {
        enviados.add(d);
        return true;
      },
    );
    await avisos.load();
    expect(avisos.tema, startsWith('alejo-'));
    await avisos.decir('PAPÁ, VENÍ', urgente: true);
    expect(enviados, isEmpty); // apagados
    // por defecto también avisa cada frase; acá se prueba con eso apagado
    expect(avisos.cadaFrase, isTrue);
    await avisos.configurar(activo: true, cadaFrase: false);
    await avisos.decir('ME DUELE MUCHO LA PANZA', urgente: true);
    await avisos.decir(
      'YO QUIERO AGUA',
      esFrase: true,
    ); // frases: solo si cadaFrase
    expect(enviados.length, 1);
    expect(enviados.single['priority'], 5);
    expect(enviados.single['title'], 'ALEJO dice');
    await avisos.configurar(cadaFrase: true);
    await avisos.decir('YO QUIERO AGUA', esFrase: true);
    expect(enviados.length, 2);
    expect(avisos.registro.length, 4);
    // se guarda y se vuelve a leer
    final otra = Avisos(dir, enviarHttp: (_) async => true);
    await otra.load();
    expect(otra.activo, isTrue);
    expect(otra.tema, avisos.tema);
    expect(otra.registro.length, 4);
  });

  test('agenda: rutina inicial, marcar pasos de hoy y guardarlos', () async {
    final store = BoardStore(dir);
    await store.load();
    expect(store.rutina.first.label, 'LEVANTARSE');
    await store.marcarHecho(store.rutina.first.id, true);
    expect(store.hechosHoy, contains(store.rutina.first.id));
    await store.elegirPrimeroDespues(
      primero: store.rutina[1],
      despues: store.rutina[7],
    );
    final otra = BoardStore(dir);
    await otra.load();
    expect(otra.hechosHoy.length, 1);
    expect(otra.primero!.label, store.rutina[1].label);
    expect(otra.despues!.label, 'JUGAR');
  });

  for (final width in [320.0, 411.0]) {
    testWidgets('"Me siento" y "Agenda" entran en $width px con letra grande', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width * 3, 760 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      late BoardStore store;
      await tester.runAsync(() async {
        store = BoardStore(dir);
        await store.load();
      });
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: Size(width, 760),
            textScaler: const TextScaler.linear(1.6),
          ),
          child: AlejoApp(store: store),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('QUIERO'), findsOneWidget); // barra de palabras clave
      await tester.tap(find.text('Me siento'));
      await tester.pumpAndSettle();
      expect(find.text('¿CÓMO TE SENTÍS?'), findsOneWidget);
      await tester.tap(find.text('Agenda'));
      await tester.pumpAndSettle();
      expect(find.text('MI DÍA'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
