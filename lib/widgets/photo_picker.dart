import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

/// Elige una foto (galería o cámara) y la deja recortar y ajustar: en
/// cuadrado para los pictogramas, libre ([square] en false) para la foto de
/// "Yo hablo". Devuelve el archivo recortado o null si se canceló.
Future<File?> pickAndCropPhoto(
  BuildContext context, {
  bool square = true,
}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library, size: 32),
            title: const Text('Elegir de la galería'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera, size: 32),
            title: const Text('Sacar una foto'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
        ],
      ),
    ),
  );
  if (source == null) return null;

  final picked = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1600,
    maxHeight: 1600,
  );
  if (picked == null || !context.mounted) return null;

  final color = Theme.of(context).colorScheme.primary;
  final cropped = await ImageCropper().cropImage(
    sourcePath: picked.path,
    aspectRatio: square ? const CropAspectRatio(ratioX: 1, ratioY: 1) : null,
    maxWidth: square ? 800 : 1200,
    maxHeight: square ? 800 : 1600,
    compressQuality: 85,
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: 'Ajustar foto',
        toolbarColor: color,
        toolbarWidgetColor: Colors.white,
        activeControlsWidgetColor: color,
        lockAspectRatio: square,
        hideBottomControls: false,
      ),
    ],
  );
  if (cropped == null) return null;
  return File(cropped.path);
}
