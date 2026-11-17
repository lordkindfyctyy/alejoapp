import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// Avisos al celular de papá (o de quien cuide a Alejo) con ntfy (https://ntfy.sh): un servicio gratis, sin cuenta, que
/// manda notificaciones. El teléfono de Alejo publica en un "tema" (un nombre largo al azar, que funciona como clave) y el
/// celular de papá, con la app ntfy suscripta a ese tema, recibe el aviso al instante.
///
/// Además guarda un registro de lo que dijo Alejo (fecha y frase), solo en este teléfono, para ver qué pide y cuándo.
class Avisos extends ChangeNotifier {
  Avisos(this.root, {this.enviarHttp});

  final Directory root;

  /// Los tests pasan una función falsa en vez de usar internet.
  final Future<bool> Function(Map<String, dynamic> datos)? enviarHttp;

  static const servidor = 'https://ntfy.sh';

  bool activo = false;
  String tema = '';
  String nombre = 'ALEJO';
  String cuidador = 'PAPÁ';

  /// Si también se avisa cada frase que dice con ▶ (no solo los pedidos de ayuda, el dolor y "vení").
  bool cadaFrase = true;

  /// Resultado del último envío (para mostrarlo en pantalla).
  String? ultimoEstado;
  final List<Map<String, String>> registro = [];

  File get _archivo => File('${root.path}/avisos.json');

  static String temaNuevo() {
    const letras = 'abcdefghijkmnpqrstuvwxyz23456789';
    final r = Random.secure();
    return 'alejo-${List.generate(14, (_) => letras[r.nextInt(letras.length)]).join()}';
  }

  Future<void> load() async {
    if (await _archivo.exists()) {
      try {
        final d = jsonDecode(await _archivo.readAsString()) as Map;
        activo = d['activo'] == true;
        tema = d['tema'] as String? ?? '';
        nombre = d['nombre'] as String? ?? nombre;
        cuidador = d['cuidador'] as String? ?? cuidador;
        cadaFrase = d['cadaFrase'] != false;
        for (final r in d['registro'] as List? ?? const []) {
          registro.add(Map<String, String>.from(r as Map));
        }
      } catch (e) {
        debugPrint('avisos.json: $e');
      }
    }
    if (tema.isEmpty) tema = temaNuevo();
    notifyListeners();
  }

  Future<void> _guardar() async {
    await root.create(recursive: true);
    final tmp = File('${_archivo.path}.tmp');
    await tmp.writeAsString(
      jsonEncode({
        'activo': activo,
        'tema': tema,
        'nombre': nombre,
        'cuidador': cuidador,
        'cadaFrase': cadaFrase,
        'registro': registro.length > 500
            ? registro.sublist(registro.length - 500)
            : registro,
      }),
    );
    await tmp.rename(_archivo.path);
  }

  Future<void> configurar({
    bool? activo,
    String? nombre,
    String? cuidador,
    bool? cadaFrase,
    bool temaNuevoAhora = false,
    String? tema,
  }) async {
    if (tema != null && tema.isNotEmpty) this.tema = tema;
    if (activo != null) this.activo = activo;
    if (nombre != null && nombre.trim().isNotEmpty) {
      this.nombre = nombre.trim().toUpperCase();
    }
    if (cuidador != null && cuidador.trim().isNotEmpty) {
      this.cuidador = cuidador.trim().toUpperCase();
    }
    if (cadaFrase != null) this.cadaFrase = cadaFrase;
    if (temaNuevoAhora) tema = temaNuevo();
    await _guardar();
    notifyListeners();
  }

  /// Anota en el registro lo que dijo (siempre) y, si los avisos están activos, lo manda al celular.
  /// [urgente]: dolor, ayuda o "vení" (llega con prioridad alta y suena aunque el celular esté en silencio, según cómo
  /// esté configurada la app ntfy).
  Future<bool> decir(
    String frase, {
    bool urgente = false,
    bool esFrase = false,
  }) async {
    registro.add({
      't': DateTime.now().toIso8601String(),
      'frase': frase,
      if (urgente) 'urgente': 'sí',
    });
    await _guardar();
    if (!activo || (esFrase && !cadaFrase && !urgente)) {
      notifyListeners();
      return false;
    }
    return enviar(frase, urgente: urgente);
  }

  Future<bool> enviar(String frase, {bool urgente = false}) async {
    final datos = {
      'topic': tema,
      'title': '$nombre dice',
      'message': frase,
      'priority': urgente ? 5 : 3,
      'tags': [urgente ? 'rotating_light' : 'speech_balloon', 'frase'],
    };
    bool ok;
    try {
      ok = enviarHttp != null ? await enviarHttp!(datos) : await _post(datos);
    } catch (e) {
      debugPrint('Aviso: $e');
      ok = false;
    }
    ultimoEstado = ok
        ? 'Aviso enviado a $cuidador'
        : 'No se pudo avisar (¿hay internet?)';
    notifyListeners();
    return ok;
  }

  Future<bool> _post(Map<String, dynamic> datos) async {
    final cliente = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await cliente.postUrl(Uri.parse(servidor));
      req.headers.contentType = ContentType.json;
      req.add(utf8.encode(jsonEncode(datos)));
      final res = await req.close().timeout(const Duration(seconds: 15));
      await res.drain<void>();
      return res.statusCode == 200;
    } finally {
      cliente.close(force: true);
    }
  }
}
