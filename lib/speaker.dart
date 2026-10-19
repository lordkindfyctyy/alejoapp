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

  /// [audioFile] es la grabación propia (ruta completa) o null. Con [wait]
  /// no vuelve hasta terminar de hablar (para decir una frase palabra por
  /// palabra).
  Future<void> say(String text, {String? audioFile, bool wait = false}) async {
    await stop();
    if (audioFile != null && await File(audioFile).exists()) {
      final done = wait ? _player.onPlayerComplete.first : null;
      await _player.play(DeviceFileSource(audioFile));
      if (done != null) {
        // Por las dudas, que una grabación trabada no frene la frase.
        await done.timeout(const Duration(seconds: 20), onTimeout: () {});
      }
      return;
    }
    await _initTts();
    try {
      await _tts.awaitSpeakCompletion(wait);
      // En minúscula: algunas voces deletrean las palabras en mayúscula
      // ("NO" → "ene o").
      await _tts.speak(text.toLowerCase());
    } catch (e) {
      debugPrint('TTS: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
      await _tts.stop();
    } catch (_) {}
  }
}
