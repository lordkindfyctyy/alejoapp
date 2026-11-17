import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../speaker.dart';

/// Graba la voz de la familia para un pictograma. Un toque empieza a grabar
/// y otro termina. [onChanged] recibe el archivo nuevo (temporal) o null si
/// se borró la grabación.
class VoiceRecorder extends StatefulWidget {
  const VoiceRecorder({
    super.key,
    required this.currentFile,
    required this.onChanged,
  });

  /// Ruta completa de la grabación actual, o null.
  final String? currentFile;
  final ValueChanged<String?> onChanged;

  @override
  State<VoiceRecorder> createState() => _VoiceRecorderState();
}

class _VoiceRecorderState extends State<VoiceRecorder> {
  final _recorder = AudioRecorder();
  bool _recording = false;
  int _seconds = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_recording) {
      _timer?.cancel();
      final path = await _recorder.stop();
      setState(() => _recording = false);
      if (path != null) widget.onChanged(path);
      return;
    }
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Para grabar hay que permitir el uso del micrófono.'),
          ),
        );
      }
      return;
    }
    await Speaker.instance.stop();
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voz_${DateTime.now().microsecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1),
      path: path,
    );
    setState(() {
      _recording = true;
      _seconds = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _seconds++);
      // Una palabra o frase corta: se corta sola a los 15 segundos.
      if (_seconds >= 15) _toggle();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final file = widget.currentFile;
    final hasFile = file != null && File(file).existsSync();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: _recording ? Colors.red : scheme.primary,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: _toggle,
          icon: Icon(_recording ? Icons.stop : Icons.mic, size: 28),
          label: Text(
            _recording
                ? 'Grabando… $_seconds s  (tocá para terminar)'
                : hasFile
                ? 'Grabar de nuevo'
                : 'Grabar mi voz',
            style: const TextStyle(fontSize: 18),
          ),
        ),
        if (hasFile && !_recording) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Speaker.instance.say('', audioFile: file),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Escuchar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => widget.onChanged(null),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Borrar voz'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
