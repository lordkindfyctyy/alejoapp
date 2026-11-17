// Pruebas de la conexión entre teléfonos. La última usa internet de verdad (ntfy.sh) y se puede saltear con
// `flutter test --exclude-tags red`.
@Tags(['red'])
library;

import 'dart:async';
import 'dart:io';

import 'package:alejoapp/avisos.dart';
import 'package:alejoapp/board_store.dart';
import 'package:alejoapp/conexion.dart';
import 'package:alejoapp/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory a, b;
  setUp(() async {
    a = await Directory.systemTemp.createTemp('alejo_a');
    b = await Directory.systemTemp.createTemp('alejo_b');
  });
  tearDown(() async {
    await a.delete(recursive: true);
    await b.delete(recursive: true);
  });

  test('paquete de botones: lo que se exporta en un teléfono aparece igual en el otro (con fotos)', () async {
    final origen = BoardStore(a);
    await origen.load();
    final foto = File('${a.path}/foto.jpg')..writeAsBytesSync(List.generate(300, (i) => i % 256));
    final rel = await origen.importMedia(foto, 'jpg');
    await origen.savePictogram('inicio', Pictogram(id: 'x1', label: 'PILETA', emoji: '🏊', imagePath: rel));
    await origen.agregarPaso(Pictogram(id: 'y', label: 'PILETA', emoji: '🏊', imagePath: rel));
    final paquete = await origen.exportarPaquete();

    final destino = BoardStore(b);
    await destino.load();
    await destino.importarPaquete(paquete);
    final p = destino.home.items.firstWhere((x) => x.label == 'PILETA');
    expect(File(destino.mediaFile(p.imagePath)!).readAsBytesSync().length, 300);
    expect(destino.rutina.last.label, 'PILETA');
  });

  test('frases a dibujos: reconoce palabras de varios términos', () async {
    final store = BoardStore(a);
    await store.load();
    final partes = store.pictosDeFrase('YO QUIERO TOMAR AGUA');
    expect(partes.map((x) => x.$1), contains('TOMAR AGUA'));
    expect(partes.firstWhere((x) => x.$1 == 'TOMAR AGUA').$2, isNotNull);
  });

  test('de punta a punta por internet: Alejo le habla a papá y papá le contesta', () async {
    final tema = Avisos.temaNuevo();
    final avisosA = Avisos(a)..activo = true;
    await avisosA.load();
    await avisosA.configurar(activo: true, tema: tema);
    final alejo = Conexion(a, avisosA);
    await alejo.load();
    await alejo.elegirRol('alejo');

    final avisosB = Avisos(b);
    await avisosB.load();
    final papa = Conexion(b, avisosB);
    await papa.load();
    await papa.elegirRol('papa', codigo: tema);

    final aPapa = Completer<Llegada>();
    final aAlejo = Completer<Llegada>();
    papa.llegadas.listen((l) => aPapa.isCompleted ? null : aPapa.complete(l));
    alejo.llegadas.listen((l) => aAlejo.isCompleted ? null : aAlejo.complete(l));
    await Future<void>.delayed(const Duration(seconds: 2)); // que se conecten

    expect(await avisosA.decir('YO QUIERO AGUA', esFrase: true), isTrue);
    final l1 = await aPapa.future.timeout(const Duration(seconds: 20));
    expect(l1.mensaje.texto, 'YO QUIERO AGUA');
    expect(l1.mensaje.deAlejo, isTrue);

    expect(await papa.mandarFrase('YA VOY'), isTrue);
    final l2 = await aAlejo.future.timeout(const Duration(seconds: 20));
    expect(l2.mensaje.texto, 'YA VOY');
    expect(l2.mensaje.deAlejo, isFalse);

    expect(papa.charla.map((m) => m.texto), containsAll(['YO QUIERO AGUA', 'YA VOY']));
    await alejo.detener();
    await papa.detener();
  }, timeout: const Timeout(Duration(seconds: 60)));
}
