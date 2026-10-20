import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'speaker.dart';

/// Una frase que dice la foto: el texto en imprenta mayúscula y,
/// opcionalmente, la voz grabada por la familia.
class Phrase {
  Phrase({required this.id, required this.text, this.audioPath});

  final String id;
  String text;

  /// Ruta relativa a la carpeta de medios, o null (voz del teléfono).
  String? audioPath;

  factory Phrase.fromJson(Map<String, dynamic> json) => Phrase(
    id: json['id'] as String,
    text: json['text'] as String? ?? '',
    audioPath: json['audioPath'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    if (audioPath != null) 'audioPath': audioPath,
  };
}

/// "Yo hablo": una foto del chico a pantalla completa que dice frases
/// moviendo la boca, para que se vea a sí mismo hablando.
class TalkingPhoto {
  TalkingPhoto({
    this.imagePath,
    this.mouthX = 0.5,
    this.mouthY = 0.62,
    this.mouthWidth = 0.22,
    List<Phrase>? phrases,
  }) : phrases = phrases ?? [];

  /// Ruta relativa a la carpeta de medios, o null si todavía no hay foto.
  String? imagePath;

  /// Centro de la boca (entre los labios) y su ancho, como fracción del
  /// ancho y el alto de la foto (0 a 1).
  double mouthX;
  double mouthY;
  double mouthWidth;

  final List<Phrase> phrases;

  static TalkingPhoto initial() => TalkingPhoto(
    phrases: [
      Phrase(id: 'f1', text: 'HOLA'),
      Phrase(id: 'f2', text: 'YO QUIERO AGUA'),
      Phrase(id: 'f3', text: 'TENGO HAMBRE'),
      Phrase(id: 'f4', text: 'TE QUIERO MUCHO'),
    ],
  );

  factory TalkingPhoto.fromJson(Map<String, dynamic> json) => TalkingPhoto(
    imagePath: json['imagePath'] as String?,
    mouthX: (json['mouthX'] as num?)?.toDouble() ?? 0.5,
    mouthY: (json['mouthY'] as num?)?.toDouble() ?? 0.62,
    mouthWidth: (json['mouthWidth'] as num?)?.toDouble() ?? 0.22,
    phrases: [
      for (final p in json['phrases'] as List? ?? const [])
        Phrase.fromJson(Map<String, dynamic>.from(p as Map)),
    ],
  );

  Map<String, dynamic> toJson() => {
    if (imagePath != null) 'imagePath': imagePath,
    'mouthX': mouthX,
    'mouthY': mouthY,
    'mouthWidth': mouthWidth,
    'phrases': [for (final p in phrases) p.toJson()],
  };
}

/// Cuánto se abre la boca en cada sílaba: la "a" bien abierta, la "i" y la
/// "u" apenas (así se parece más a alguien hablando).
List<double> syllableOpenings(String word) {
  final openings = [
    for (final m in RegExp('[aeiouáéíóúü]+').allMatches(word.toLowerCase()))
      // En "ai" o "ue" manda la vocal más abierta.
      m[0]!.contains(RegExp('[aá]'))
          ? 1.0
          : m[0]!.contains(RegExp('[eéoó]'))
          ? 0.8
          : 0.55,
  ];
  return openings.isEmpty ? [0.7] : openings;
}

/// Una sílaba en el tiempo: la boca se abre y se cierra entre [start] y
/// [start] + [length].
class MouthPulse {
  const MouthPulse(this.word, this.start, this.length, this.amount);

  final int word;
  final Duration start;
  final Duration length;
  final double amount;

  Duration get end => start + length;
}

/// Duración de una sílaba con la voz del teléfono a la velocidad de la app.
const kSyllable = Duration(milliseconds: 210);
const _wordGap = Duration(milliseconds: 90);

/// Las sílabas de [words] una atrás de otra desde [from] (cuando no se sabe
/// en qué momento empieza cada palabra).
List<MouthPulse> estimatePulses(
  List<String> words, {
  Duration from = Duration.zero,
  Duration syllable = kSyllable,
}) {
  final pulses = <MouthPulse>[];
  var t = from;
  for (var i = 0; i < words.length; i++) {
    for (final amount in syllableOpenings(words[i])) {
      pulses.add(MouthPulse(i, t, syllable, amount));
      t += syllable;
    }
    t += _wordGap;
  }
  return pulses;
}

/// Qué tan abierta está la boca (0 cerrada, 1 bien abierta) en [t].
double mouthOpening(List<MouthPulse> pulses, Duration t) {
  var open = 0.0;
  for (final p in pulses) {
    if (t < p.start || t > p.end) continue;
    final x = (t - p.start).inMicroseconds / p.length.inMicroseconds;
    open = max(open, sin(pi * x) * p.amount);
  }
  return open;
}

/// La palabra que se está diciendo en [t], o null.
int? wordAt(List<MouthPulse> pulses, Duration t) {
  // La última sílaba que ya empezó; sigue resaltada en la pausa siguiente.
  for (final p in pulses.reversed) {
    if (t >= p.start) return t <= p.end + _wordGap ? p.word : null;
  }
  return null;
}

/// Índice de la palabra que empieza en el carácter [offset] de [text].
int wordIndexAt(String text, int offset) {
  var index = -1;
  for (final m in RegExp(r'\S+').allMatches(text)) {
    if (m.start > offset) break;
    index++;
  }
  return max(index, 0);
}

typedef TalkFn = Future<void> Function(
  String text, {
  String? audioFile,
  void Function(int start, int end)? onWord,
});
typedef AudioLengthFn = Future<Duration?> Function(String file);

/// Hace hablar a la foto: dice la frase y calcula, momento a momento, cuánto
/// se abre la boca y qué palabra resaltar.
class TalkingController extends ChangeNotifier {
  TalkingController({TalkFn? talk, AudioLengthFn? audioLength})
    : _talk = talk ?? Speaker.instance.talk,
      _audioLength = audioLength ?? Speaker.instance.audioLength;

  final TalkFn _talk;
  final AudioLengthFn _audioLength;
  final _clock = Stopwatch();
  List<MouthPulse> _pulses = const [];
  List<String> _words = const [];
  int? _word;
  bool _speaking = false;
  int _run = 0;

  bool get speaking => _speaking;
  List<String> get words => _words;

  /// La palabra que se está diciendo (para resaltarla), o null.
  int? get word => _word;

  /// Qué tan abierta está la boca ahora.
  double get opening => _speaking ? mouthOpening(_pulses, _clock.elapsed) : 0;

  /// Lo llama la pantalla en cada cuadro: avisa si cambió la palabra.
  void tick() {
    if (!_speaking) return;
    final w = wordAt(_pulses, _clock.elapsed);
    if (w != null && w != _word) {
      _word = w;
      notifyListeners();
    }
  }

  Future<void> say(String text, {String? audioFile}) async {
    final run = ++_run;
    _words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (_words.isEmpty) return;
    _pulses = const [];
    _word = 0;
    _speaking = true;
    notifyListeners();

    if (audioFile != null) {
      // Grabación propia: las sílabas se reparten a lo largo de la grabación.
      final length = await _audioLength(audioFile);
      final rough = estimatePulses(_words);
      final total = rough.last.end;
      final scale = length == null || total == Duration.zero
          ? 1.0
          : (length * 0.92).inMicroseconds / total.inMicroseconds;
      _pulses = [
        for (final p in rough)
          MouthPulse(p.word, p.start * scale, p.length * scale, p.amount),
      ];
      _clock
        ..reset()
        ..start();
      await _talk(text, audioFile: audioFile);
    } else {
      // Voz del teléfono: cada palabra se mueve cuando la voz la empieza a
      // decir. Si el teléfono no avisa las palabras, se estima.
      var heard = false;
      final fallback = Timer(const Duration(milliseconds: 700), () {
        if (!heard && run == _run) {
          _pulses = estimatePulses(_words, from: _clock.elapsed);
        }
      });
      _clock
        ..reset()
        ..start();
      final spoken = text.toLowerCase();
      await _talk(
        text,
        onWord: (start, end) {
          if (run != _run) return;
          heard = true;
          final i = wordIndexAt(spoken, start);
          if (i >= _words.length) return;
          final now = _clock.elapsed;
          _pulses = [
            for (final p in _pulses)
              if (p.word != i) p,
            for (final (k, amount) in syllableOpenings(_words[i]).indexed)
              MouthPulse(i, now + kSyllable * k, kSyllable, amount),
          ];
        },
      );
      fallback.cancel();
    }
    // Que termine la última sílaba antes de cerrar la boca.
    final rest = _pulses.isEmpty
        ? Duration.zero
        : _pulses.last.end - _clock.elapsed;
    if (rest > Duration.zero && rest < const Duration(seconds: 3)) {
      await Future<void>.delayed(rest);
    }
    if (run != _run) return;
    _speaking = false;
    _word = null;
    _clock.stop();
    notifyListeners();
  }
}
