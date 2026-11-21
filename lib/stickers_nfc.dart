import 'dart:async';

import 'package:flutter/services.dart';

import 'models.dart';

/// Stickers NFC de la casa: se pega uno en la heladera, otro en el baño, otro en la cama... Se graban desde
/// Ajustes con el pictograma que corresponde y, cuando Alejo apoya el celular, la app se abre y muestra ese
/// pictograma en grande y lo dice (widgets/lugares_nfc.dart). La parte de Android está en MainActivity.kt.
///
/// El sticker guarda `alejoapp://picto/<id>?l=<NOMBRE>`: el id para encontrar el botón y el nombre por si el botón
/// se borró o cambió de id (por ejemplo, si se importaron los botones desde el teléfono de papá).
class StickersNfc {
  StickersNfc._() {
    _canal.setMethodCallHandler((llamada) async {
      if (llamada.method == 'abrir' && llamada.arguments is String) {
        _toques.add(llamada.arguments as String);
      }
    });
  }

  static final StickersNfc instancia = StickersNfc._();
  static const _canal = MethodChannel('alejoapp/nfc');

  final _toques = StreamController<String>.broadcast();

  /// Links de los stickers que tocan con la app abierta.
  Stream<String> get toques => _toques.stream;

  /// 'sin' (este teléfono no tiene NFC), 'apagado' o 'listo'.
  Future<String> estado() async {
    try {
      return await _canal.invokeMethod<String>('estado') ?? 'sin';
    } catch (_) {
      return 'sin';
    }
  }

  /// El link del sticker que abrió la app (solo la primera vez que se pregunta).
  Future<String?> linkInicial() async {
    try {
      return await _canal.invokeMethod<String>('linkInicial');
    } catch (_) {
      return null;
    }
  }

  /// Espera hasta 60 s a que acerquen un sticker y le graba el pictograma. Devuelve 'ok' o qué pasó.
  Future<String> grabar(Pictogram picto) async {
    try {
      return await _canal.invokeMethod<String>('grabar', {
            'uri': linkDe(picto),
          }) ??
          'No se pudo grabar';
    } catch (_) {
      return 'Este teléfono no puede grabar stickers NFC';
    }
  }

  Future<void> cancelar() async {
    try {
      await _canal.invokeMethod<void>('cancelar');
    } catch (_) {}
  }

  static String linkDe(Pictogram picto) => Uri(
    scheme: 'alejoapp',
    host: 'picto',
    path: '/${picto.id}',
    queryParameters: {'l': picto.label},
  ).toString();

  /// Lo que dice un link de sticker: (id, nombre). null si no es de AlejoApp.
  static ({String id, String nombre})? leer(String link) {
    final uri = Uri.tryParse(link);
    if (uri == null || uri.scheme != 'alejoapp' || uri.host != 'picto') {
      return null;
    }
    final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    return (id: id, nombre: uri.queryParameters['l'] ?? '');
  }
}
