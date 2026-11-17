import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'default_boards.dart';
import 'models.dart';
import 'talking.dart';

/// Guarda los tableros en el teléfono (sin internet ni cuentas): un
/// `tableros.json` y una carpeta `medios/` con las fotos y las grabaciones.
class BoardStore extends ChangeNotifier {
  BoardStore(this.root);

  /// Carpeta de datos de la app (getApplicationDocumentsDirectory en el
  /// teléfono; una carpeta temporal en los tests).
  final Directory root;

  final List<Board> _boards = [];
  TalkingPhoto _talking = TalkingPhoto.initial();

  // ---- Agenda visual ----
  /// La rutina del día, en orden.
  final List<Pictogram> rutina = [];

  /// "Primero ... después ..." (null = sin elegir).
  Pictogram? primero, despues;

  /// Qué pasos de la rutina ya hizo hoy (se reinicia cada día).
  String _hechosFecha = '';
  final Set<String> _hechos = {};
  bool _loaded = false;

  /// La foto de "Yo hablo" y sus frases.
  TalkingPhoto get talking => _talking;

  bool get loaded => _loaded;

  File get _dataFile => File('${root.path}/tableros.json');
  Directory get mediaDir => Directory('${root.path}/medios');

  Board get home => _boards.firstWhere((b) => b.id == kHomeBoardId);

  /// Las categorías, sin el tablero de inicio.
  List<Board> get categories =>
      _boards.where((b) => b.id != kHomeBoardId).toList(growable: false);

  Board board(String id) => _boards.firstWhere((b) => b.id == id);

  Future<void> load() async {
    _boards.clear();
    if (await _dataFile.exists()) {
      try {
        final data = jsonDecode(await _dataFile.readAsString()) as Map;
        for (final b in data['tableros'] as List) {
          _boards.add(Board.fromJson(Map<String, dynamic>.from(b as Map)));
        }
        final agenda = data['agenda'];
        if (agenda is Map) {
          for (final p in agenda['rutina'] as List? ?? const []) {
            rutina.add(Pictogram.fromJson(Map<String, dynamic>.from(p as Map)));
          }
          if (agenda['primero'] is Map) {
            primero = Pictogram.fromJson(
              Map<String, dynamic>.from(agenda['primero'] as Map),
            );
          }
          if (agenda['despues'] is Map) {
            despues = Pictogram.fromJson(
              Map<String, dynamic>.from(agenda['despues'] as Map),
            );
          }
          _hechosFecha = agenda['hechosFecha'] as String? ?? '';
          _hechos.addAll([
            for (final x in agenda['hechos'] as List? ?? const []) x as String,
          ]);
        }
        final talking = data['yoHablo'];
        if (talking is Map) {
          _talking = TalkingPhoto.fromJson(Map<String, dynamic>.from(talking));
        }
      } catch (e) {
        debugPrint('No se pudo leer tableros.json: $e');
        _boards.clear();
      }
    }
    if (!_boards.any((b) => b.id == kHomeBoardId)) {
      _boards
        ..clear()
        ..addAll(defaultBoards());
      await _save();
    }
    if (rutina.isEmpty) rutina.addAll(defaultRoutine());
    await mediaDir.create(recursive: true);
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    await root.create(recursive: true);
    // Se escribe en un archivo aparte y se renombra, para no perder los
    // tableros si el teléfono se apaga a mitad de la escritura.
    final tmp = File('${_dataFile.path}.tmp');
    await tmp.writeAsString(
      jsonEncode({
        'version': 1,
        'tableros': [for (final b in _boards) b.toJson()],
        'yoHablo': _talking.toJson(),
        'agenda': {
          'rutina': [for (final p in rutina) p.toJson()],
          if (primero != null) 'primero': primero!.toJson(),
          if (despues != null) 'despues': despues!.toJson(),
          'hechosFecha': _hechosFecha,
          'hechos': _hechos.toList(),
        },
      }),
    );
    await tmp.rename(_dataFile.path);
  }

  Future<void> _commit() async {
    await _save();
    notifyListeners();
  }

  /// Ruta completa de un archivo de medios guardado como ruta relativa.
  String? mediaFile(String? relative) =>
      relative == null ? null : '${mediaDir.path}/$relative';

  /// Copia [source] a la carpeta de medios y devuelve su ruta relativa.
  Future<String> importMedia(File source, String extension) async {
    await mediaDir.create(recursive: true);
    final name = '${DateTime.now().microsecondsSinceEpoch}.$extension';
    await source.copy('${mediaDir.path}/$name');
    return name;
  }

  Future<void> deleteMedia(String? relative) async {
    final path = mediaFile(relative);
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  // ---- Pictogramas ----

  Future<void> savePictogram(String boardId, Pictogram picto) async {
    final items = board(boardId).items;
    final i = items.indexWhere((p) => p.id == picto.id);
    if (i >= 0) {
      items[i] = picto;
    } else {
      items.add(picto);
    }
    await _commit();
  }

  Future<void> deletePictogram(String boardId, Pictogram picto) async {
    board(boardId).items.removeWhere((p) => p.id == picto.id);
    await deleteUnusedMedia([picto.imagePath, picto.audioPath]);
    await _commit();
  }

  Future<void> movePictogram(String boardId, int from, int to) async {
    final items = board(boardId).items;
    if (from == to || from < 0 || from >= items.length) return;
    final picto = items.removeAt(from);
    items.insert(to.clamp(0, items.length), picto);
    await _commit();
  }

  // ---- Categorías ----

  Future<void> saveCategory(Board category) async {
    final i = _boards.indexWhere((b) => b.id == category.id);
    if (i >= 0) {
      _boards[i] = category;
    } else {
      _boards.add(category);
    }
    await _commit();
  }

  /// Mueve una categoría de lugar ([from] y [to] cuentan solo las
  /// categorías, sin el tablero de inicio).
  Future<void> moveCategory(int from, int to) async {
    final cats = categories.toList();
    if (from == to || from < 0 || from >= cats.length) return;
    final category = cats.removeAt(from);
    cats.insert(to.clamp(0, cats.length), category);
    final start = home;
    _boards
      ..clear()
      ..add(start)
      ..addAll(cats);
    await _commit();
  }

  Future<void> deleteCategory(Board category) async {
    if (category.id == kHomeBoardId) return;
    _boards.removeWhere((b) => b.id == category.id);
    await deleteUnusedMedia([
      category.imagePath,
      for (final p in category.items) ...[p.imagePath, p.audioPath],
    ]);
    await _commit();
  }

  // ---- Agenda visual ----

  static String _hoy() => DateTime.now().toIso8601String().substring(0, 10);

  /// Los pasos de la rutina que ya hizo hoy.
  Set<String> get hechosHoy =>
      _hechosFecha == _hoy() ? Set.unmodifiable(_hechos) : const {};

  Future<void> marcarHecho(String id, bool hecho) async {
    if (_hechosFecha != _hoy()) {
      _hechos.clear();
      _hechosFecha = _hoy();
    }
    hecho ? _hechos.add(id) : _hechos.remove(id);
    await _commit();
  }

  Future<void> reiniciarDia() async {
    _hechos.clear();
    _hechosFecha = _hoy();
    await _commit();
  }

  /// Suma un paso a la rutina (una copia del pictograma, con su foto y su voz).
  Future<void> agregarPaso(Pictogram p) async {
    rutina.add(
      Pictogram(
        id: newId(),
        label: p.label,
        emoji: p.emoji,
        imagePath: p.imagePath,
        audioPath: p.audioPath,
      ),
    );
    await _commit();
  }

  Future<void> borrarPaso(String id) async {
    rutina.removeWhere((p) => p.id == id);
    await _commit();
  }

  Future<void> moverPaso(int desde, int hasta) async {
    if (desde == hasta || desde < 0 || desde >= rutina.length) return;
    final p = rutina.removeAt(desde);
    rutina.insert(hasta.clamp(0, rutina.length), p);
    await _commit();
  }

  Future<void> elegirPrimeroDespues({
    Pictogram? primero,
    Pictogram? despues,
  }) async {
    Pictogram copia(Pictogram p) => Pictogram(
      id: newId(),
      label: p.label,
      emoji: p.emoji,
      imagePath: p.imagePath,
      audioPath: p.audioPath,
    );
    if (primero != null) this.primero = copia(primero);
    if (despues != null) this.despues = copia(despues);
    await _commit();
  }

  /// Todos los pictogramas de todos los tableros (para elegir pasos de la agenda), sin repetir palabras.
  List<Pictogram> todosLosPictogramas() {
    final vistos = <String>{};
    return [
      for (final b in _boards)
        for (final p in b.items)
          if (vistos.add(p.label)) p,
    ];
  }

  // ---- Yo hablo ----

  /// Cambia la foto o dónde está la boca; borra la foto anterior.
  Future<void> saveTalkingPhoto({
    String? imagePath,
    double? mouthX,
    double? mouthY,
    double? mouthWidth,
  }) async {
    final old = _talking.imagePath;
    if (imagePath != null) _talking.imagePath = imagePath;
    if (mouthX != null) _talking.mouthX = mouthX.clamp(0, 1);
    if (mouthY != null) _talking.mouthY = mouthY.clamp(0, 1);
    if (mouthWidth != null) _talking.mouthWidth = mouthWidth.clamp(0.05, 0.6);
    if (imagePath != null && old != imagePath) await deleteUnusedMedia([old]);
    await _commit();
  }

  Future<void> savePhrase(Phrase phrase) async {
    final list = _talking.phrases;
    final i = list.indexWhere((p) => p.id == phrase.id);
    final oldAudio = i >= 0 ? list[i].audioPath : null;
    if (i >= 0) {
      list[i] = phrase;
    } else {
      list.add(phrase);
    }
    if (oldAudio != phrase.audioPath) await deleteUnusedMedia([oldAudio]);
    await _commit();
  }

  Future<void> deletePhrase(Phrase phrase) async {
    _talking.phrases.removeWhere((p) => p.id == phrase.id);
    await deleteUnusedMedia([phrase.audioPath]);
    await _commit();
  }

  /// Borra los archivos que ya no usa ningún tablero (la misma foto puede
  /// estar en más de un pictograma si se copió).
  Future<void> deleteUnusedMedia(List<String?> candidates) async {
    final inUse = <String>{
      if (_talking.imagePath != null) _talking.imagePath!,
      for (final p in _talking.phrases)
        if (p.audioPath != null) p.audioPath!,
      for (final p in [...rutina, ?primero, ?despues]) ...[
        if (p.imagePath != null) p.imagePath!,
        if (p.audioPath != null) p.audioPath!,
      ],
      for (final b in _boards) ...[
        if (b.imagePath != null) b.imagePath!,
        for (final p in b.items) ...[
          if (p.imagePath != null) p.imagePath!,
          if (p.audioPath != null) p.audioPath!,
        ],
      ],
    };
    for (final c in candidates) {
      if (c != null && !inUse.contains(c)) await deleteMedia(c);
    }
  }
}
