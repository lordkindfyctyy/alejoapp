import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'avisos.dart';

/// Un mensaje de la charla entre el teléfono de Alejo y el de papá.
class Mensaje {
  Mensaje({
    required this.id,
    required this.deAlejo,
    required this.t,
    required this.tipo,
    this.texto = '',
    this.audio,
  });

  final String id;
  final bool deAlejo;
  final DateTime t;

  /// 'frase' (palabras), 'voz' (grabación), 'tableros' (botones enviados).
  final String tipo;
  final String texto;

  /// Ruta local de la grabación (mensajes de voz).
  String? audio;

  factory Mensaje.fromJson(Map<String, dynamic> j) => Mensaje(
    id: j['id'] as String,
    deAlejo: j['deAlejo'] == true,
    t: DateTime.tryParse(j['t'] as String? ?? '') ?? DateTime.now(),
    tipo: j['tipo'] as String? ?? 'frase',
    texto: j['texto'] as String? ?? '',
    audio: j['audio'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'deAlejo': deAlejo,
    't': t.toIso8601String(),
    'tipo': tipo,
    'texto': texto,
    if (audio != null) 'audio': audio,
  };
}

/// Algo que llegó del otro teléfono (con el adjunto, si trae: voz o botones).
class Llegada {
  Llegada(this.mensaje, {this.adjuntoUrl, this.adjuntoNombre});
  final Mensaje mensaje;
  final String? adjuntoUrl, adjuntoNombre;
}

/// Conexión entre el teléfono de Alejo y el de papá, por ntfy (los mismos canales que los avisos):
/// - canal `tema`: de Alejo a papá (sus frases, avisos y sus botones cuando papá los pide).
/// - canal `tema-p`: de papá a Alejo (frases, mensajes de voz, botones nuevos y pedidos).
///
/// Mientras la app está abierta queda escuchando el canal del otro (llega al instante). Si estaba cerrada, al abrirla
/// recupera lo que llegó en las últimas horas (ntfy lo guarda unas 12 h).
class Conexion extends ChangeNotifier {
  Conexion(this.root, this.avisos, {this.sinRed = false});

  final Directory root;
  final Avisos avisos;

  /// En las pruebas no se conecta a internet.
  final bool sinRed;

  /// Cada cosa que llega del otro teléfono (la pantalla principal la dice, la muestra o aplica los botones).
  final _llegadas = StreamController<Llegada>.broadcast();
  Stream<Llegada> get llegadas => _llegadas.stream;

  /// 'alejo' o 'papa'.
  String rol = 'alejo';
  final List<Mensaje> charla = [];
  final Map<String, String> _ultimoId = {};
  bool conectado = false;
  String? error;

  HttpClient? _cliente;
  StreamSubscription<String>? _escucha;
  Timer? _reintento;
  bool _activa = false;

  bool get esPapa => rol == 'papa';
  String get canalAlejo => avisos.tema;
  String get canalPapa => '${avisos.tema}-p';
  String get _canalQueEscucho => esPapa ? canalAlejo : canalPapa;

  File get _archivo => File('${root.path}/conexion.json');
  Directory get carpetaVoces => Directory('${root.path}/voces');

  Future<void> load() async {
    if (await _archivo.exists()) {
      try {
        final d = jsonDecode(await _archivo.readAsString()) as Map;
        rol = d['rol'] as String? ?? 'alejo';
        _ultimoId.addAll(
          Map<String, String>.from(d['ultimoId'] as Map? ?? const {}),
        );
        for (final m in d['charla'] as List? ?? const []) {
          charla.add(Mensaje.fromJson(Map<String, dynamic>.from(m as Map)));
        }
      } catch (e) {
        debugPrint('conexion.json: $e');
      }
    }
    notifyListeners();
  }

  Future<void> _guardar() async {
    await root.create(recursive: true);
    final tmp = File('${_archivo.path}.tmp');
    final ultimos = charla.length > 300
        ? charla.sublist(charla.length - 300)
        : charla;
    await tmp.writeAsString(
      jsonEncode({
        'rol': rol,
        'ultimoId': _ultimoId,
        'charla': [for (final m in ultimos) m.toJson()],
      }),
    );
    await tmp.rename(_archivo.path);
  }

  /// Este teléfono pasa a ser de papá (con el código del teléfono de Alejo) o de Alejo.
  Future<void> elegirRol(String nuevo, {String? codigo}) async {
    rol = nuevo;
    if (codigo != null && codigo.trim().isNotEmpty) {
      await avisos.configurar(activo: true, tema: codigo.trim().toLowerCase());
    }
    _ultimoId.clear();
    await _guardar();
    notifyListeners();
    await reiniciar();
  }

  Future<void> anotar(Mensaje m) async {
    if (charla.any((x) => x.id == m.id)) return;
    charla.add(m);
    await _guardar();
    notifyListeners();
  }

  // ------------------------------------------------------------------ escuchar el canal del otro teléfono
  Future<void> iniciar() async {
    if (sinRed) return;
    _activa = true;
    await _conectar();
  }

  Future<void> detener() async {
    _activa = false;
    _reintento?.cancel();
    await _escucha?.cancel();
    _cliente?.close(force: true);
    _escucha = null;
    _cliente = null;
    conectado = false;
    notifyListeners();
  }

  Future<void> reiniciar() async {
    await detener();
    await iniciar();
  }

  Future<void> _conectar() async {
    if (!_activa || avisos.tema.isEmpty || _escucha != null) return;
    final canal = _canalQueEscucho;
    final desde = _ultimoId[canal] ?? '12h';
    try {
      _cliente = HttpClient()..connectionTimeout = const Duration(seconds: 15);
      final req = await _cliente!.getUrl(
        Uri.parse('${Avisos.servidor}/$canal/json?since=$desde'),
      );
      final res = await req.close();
      if (res.statusCode != 200) {
        throw HttpException('ntfy respondió ${res.statusCode}');
      }
      conectado = true;
      error = null;
      notifyListeners();
      _escucha = res
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (linea) => _procesar(canal, linea),
            onDone: _caida,
            onError: (Object e) => _caida(),
            cancelOnError: true,
          );
    } catch (e) {
      error = 'Sin conexión';
      _caida();
    }
  }

  void _caida() {
    _escucha = null;
    _cliente?.close(force: true);
    _cliente = null;
    if (conectado) {
      conectado = false;
      notifyListeners();
    }
    if (_activa) {
      _reintento?.cancel();
      _reintento = Timer(const Duration(seconds: 5), _conectar);
    }
  }

  Future<void> _procesar(String canal, String linea) async {
    if (linea.trim().isEmpty) return;
    Map<String, dynamic> ev;
    try {
      ev = Map<String, dynamic>.from(jsonDecode(linea) as Map);
    } catch (_) {
      return;
    }
    if (ev['event'] != 'message') return;
    _ultimoId[canal] = ev['id'] as String;
    final tags = [
      for (final t in ev['tags'] as List? ?? const []) t.toString(),
    ];
    final adj = ev['attachment'] is Map
        ? Map<String, dynamic>.from(ev['attachment'] as Map)
        : null;
    final tipo = tags.contains('voz')
        ? 'voz'
        : tags.contains('tableros')
        ? 'tableros'
        : tags.contains('pedir')
        ? 'pedir'
        : 'frase';
    final m = Mensaje(
      id: ev['id'] as String,
      deAlejo: !esPapa,
      t: DateTime.fromMillisecondsSinceEpoch(
        ((ev['time'] as num?) ?? 0).toInt() * 1000,
      ),
      tipo: tipo,
      texto: tipo == 'frase' ? (ev['message'] as String? ?? '') : '',
    );
    // de quién es: lo que escucho siempre lo mandó el otro teléfono
    final recibido = Mensaje(
      id: m.id,
      deAlejo: esPapa,
      t: m.t,
      tipo: m.tipo,
      texto: m.texto,
    );
    // lo de hace más de 12 h ya se vio: solo se anota en la charla, no se vuelve a decir
    if (DateTime.now().difference(m.t) > const Duration(hours: 12)) return;
    if (tipo != 'pedir') await anotar(recibido);
    await _guardar();
    _llegadas.add(
      Llegada(
        recibido,
        adjuntoUrl: adj?['url'] as String?,
        adjuntoNombre: adj?['name'] as String?,
      ),
    );
  }

  // ------------------------------------------------------------------ mandar al otro teléfono
  String get _canalQueMando => esPapa ? canalPapa : canalAlejo;

  /// Papá le manda una frase a Alejo (en el teléfono de Alejo se dice en voz alta).
  Future<bool> mandarFrase(String texto) async {
    final ok = await _post({
      'topic': _canalQueMando,
      'title': '${avisos.cuidador} dice',
      'message': texto,
      'tags': ['frase'],
    });
    if (ok) {
      await anotar(
        Mensaje(
          id: 'yo-${DateTime.now().microsecondsSinceEpoch}',
          deAlejo: !esPapa,
          t: DateTime.now(),
          tipo: 'frase',
          texto: texto,
        ),
      );
    }
    return ok;
  }

  /// Manda un archivo (voz o botones) como adjunto de ntfy.
  Future<bool> mandarArchivo(File f, String nombre, String tipo) async {
    final cliente = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await cliente.putUrl(
        Uri.parse('${Avisos.servidor}/$_canalQueMando'),
      );
      req.headers.set('Filename', nombre);
      req.headers.set('Tags', tipo);
      req.headers.set('Title', tipo == 'voz' ? 'Mensaje de voz' : 'Botones');
      req.contentLength = await f.length();
      await req.addStream(f.openRead());
      final res = await req.close().timeout(const Duration(seconds: 120));
      await res.drain<void>();
      final ok = res.statusCode == 200;
      if (ok) {
        await anotar(
          Mensaje(
            id: 'yo-${DateTime.now().microsecondsSinceEpoch}',
            deAlejo: !esPapa,
            t: DateTime.now(),
            tipo: tipo,
            audio: tipo == 'voz' ? f.path : null,
          ),
        );
      }
      return ok;
    } catch (e) {
      debugPrint('Adjunto: $e');
      return false;
    } finally {
      cliente.close(force: true);
    }
  }

  /// Papá le pide al teléfono de Alejo que le mande sus botones.
  Future<bool> pedirTableros() => _post({
    'topic': canalPapa,
    'title': 'Pedido',
    'message': 'pedir-tableros',
    'tags': ['pedir'],
  });

  Future<bool> _post(Map<String, dynamic> datos) async {
    final cliente = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await cliente.postUrl(Uri.parse(Avisos.servidor));
      req.headers.contentType = ContentType.json;
      req.add(utf8.encode(jsonEncode(datos)));
      final res = await req.close().timeout(const Duration(seconds: 15));
      await res.drain<void>();
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Mandar: $e');
      return false;
    } finally {
      cliente.close(force: true);
    }
  }

  /// Baja un adjunto (voz o botones) a un archivo local.
  Future<File?> bajar(String url, String nombre) async {
    final cliente = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final res = await (await cliente.getUrl(Uri.parse(url)))
          .close()
          .timeout(const Duration(seconds: 120));
      if (res.statusCode != 200) return null;
      await carpetaVoces.create(recursive: true);
      final f = File(
        '${carpetaVoces.path}/${DateTime.now().microsecondsSinceEpoch}_$nombre',
      );
      await res.pipe(f.openWrite());
      return f;
    } catch (e) {
      debugPrint('Bajar: $e');
      return null;
    } finally {
      cliente.close(force: true);
    }
  }
}
