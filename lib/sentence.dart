import 'package:flutter/foundation.dart';

import 'models.dart';
import 'speaker.dart';

/// Cómo se dice algo en voz alta (Speaker.say; los tests pasan otra).
typedef SayFn = Future<void> Function(
  String text, {
  String? audioFile,
  bool wait,
});

/// Una palabra de la frase: una copia del pictograma tal como estaba al
/// tocarlo (si después se edita o se borra, la frase no se rompe).
class SentenceWord {
  SentenceWord({
    required this.label,
    required this.emoji,
    this.imageFile,
    this.audioFile,
  });

  final String label;
  final String emoji;

  /// Rutas completas de la foto y de la grabación propia, o null.
  final String? imageFile;
  final String? audioFile;
}

/// La frase que se va armando arriba del tablero: cada pictograma que se toca
/// se suma al final ("YO" + "QUIERO" + "AGUA") y con ▶ se dice entera.
class Sentence extends ChangeNotifier {
  Sentence({SayFn? say}) : _say = say ?? Speaker.instance.say;

  /// Más palabras no entran en la tira y ya no es una frase.
  static const maxWords = 12;

  final SayFn _say;
  final List<SentenceWord> _words = [];
  int? _speaking;

  List<SentenceWord> get words => List.unmodifiable(_words);
  bool get isEmpty => _words.isEmpty;

  /// La palabra que se está diciendo ahora (para resaltarla), o null.
  int? get speaking => _speaking;

  /// Toda la frase como texto, p. ej. "YO QUIERO AGUA".
  String get text => _words.map((w) => w.label).join(' ');

  void add(Pictogram picto, {String? imageFile, String? audioFile}) {
    if (_words.length >= maxWords) return;
    _words.add(
      SentenceWord(
        label: picto.label,
        emoji: picto.emoji,
        imageFile: imageFile,
        audioFile: audioFile,
      ),
    );
    notifyListeners();
  }

  void removeLast() {
    if (_words.isEmpty) return;
    _words.removeLast();
    notifyListeners();
  }

  void clear() {
    if (_words.isEmpty) return;
    _words.clear();
    _speaking = null;
    notifyListeners();
  }

  /// Dice la frase entera. Si ninguna palabra tiene grabación propia, la dice
  /// de una sola vez con la voz del teléfono (suena más natural); si no,
  /// palabra por palabra, cada una con su grabación o con la voz.
  Future<void> speak() async {
    if (_words.isEmpty) return;
    final words = List.of(_words);
    if (words.every((w) => w.audioFile == null)) {
      _setSpeaking(null);
      await _say(text);
      return;
    }
    for (var i = 0; i < words.length; i++) {
      // Si mientras tanto se borró la frase, cortar.
      if (_words.isEmpty) break;
      _setSpeaking(i);
      await _say(words[i].label, audioFile: words[i].audioFile, wait: true);
    }
    _setSpeaking(null);
  }

  void _setSpeaking(int? i) {
    _speaking = i;
    notifyListeners();
  }
}
