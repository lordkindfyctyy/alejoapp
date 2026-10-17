import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Dice un pictograma en voz alta: con la grabación propia si la tiene, y si
/// no con la voz del teléfono en castellano.
class Speaker {
  Speaker._();
  static final Speaker instance = Speaker._();

  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _player = AudioPlayer();
  bool _ttsReady = false;

  Future<void> _initTts() async {
    if (_ttsReady) return;
    _ttsReady = true;
    try {
      // Primero castellano rioplatense; si el teléfono no lo tiene, el
      // castellano que haya.
      for (final lang in ['es-AR', 'es-US', 'es-419', 'es-ES', 'es']) {
        final ok = await _tts.isLanguageAvailable(lang);
        if (ok == true || ok == 1) {
          await _tts.setLanguage(lang);
          break;
        }
      }
      await _tts.setSpeechRate(0.45);
    } catch (e) {
      debugPrint('TTS: $e');
    }
  }

  /// [audioFile] es la grabación propia (ruta completa) o null.
  Future<void> say(String text, {String? audioFile}) async {
    await stop();
    if (audioFile != null && await File(audioFile).exists()) {
      await _player.play(DeviceFileSource(audioFile));
      return;
    }
    await _initTts();
    // En minúscula: algunas voces deletrean las palabras en mayúscula
    // ("NO" → "ene o").
    await _tts.speak(text.toLowerCase());
  }

  Future<void> stop() async {
    try {
      await _player.stop();
      await _tts.stop();
    } catch (_) {}
  }
}
