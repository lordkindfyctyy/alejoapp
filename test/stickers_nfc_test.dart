import 'dart:io';

import 'package:alejoapp/board_store.dart';
import 'package:alejoapp/models.dart';
import 'package:alejoapp/stickers_nfc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'el link del sticker lleva el id y el nombre, y se vuelve a leer igual',
    () {
      final picto = Pictogram(id: 'abc 1', label: 'HELADERA', emoji: '🧊');
      final link = StickersNfc.linkDe(picto);
      expect(link, startsWith('alejoapp://picto/'));
      final datos = StickersNfc.leer(link)!;
      expect(datos.id, 'abc 1');
      expect(datos.nombre, 'HELADERA');
      expect(StickersNfc.leer('https://otra.cosa/picto/x'), isNull);
      expect(StickersNfc.leer('alejoapp://otro/x'), isNull);
    },
  );

  test('encuentra el pictograma por id y, si no está, por el nombre', () async {
    final dir = await Directory.systemTemp.createTemp('alejo_nfc');
    addTearDown(() => dir.delete(recursive: true));
    final store = BoardStore(dir);
    await store.load();
    final alguno = store.todosLosPictogramas().first;
    expect(store.pictogramaDeSticker(alguno.id, 'otro nombre')?.id, alguno.id);
    expect(
      store.pictogramaDeSticker('no-existe', alguno.label.toLowerCase())?.label,
      alguno.label,
    );
    expect(store.pictogramaDeSticker('no-existe', 'NADA PARECIDO'), isNull);
  });
}
