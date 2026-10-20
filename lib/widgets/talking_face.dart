import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../talking.dart';

/// Dónde queda la foto en la pantalla: la foto ocupa todo el lugar (se
/// recorta lo que sobra) y estas cuentas pasan de la foto a la pantalla y al
/// revés, para dibujar la boca y para marcarla con el dedo.
class PhotoLayout {
  PhotoLayout(Size image, Size screen) {
    final fitted = applyBoxFit(BoxFit.cover, image, screen);
    source = Alignment.center.inscribe(fitted.source, Offset.zero & image);
    destination = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & screen,
    );
    imageSize = image;
  }

  late final Rect source;
  late final Rect destination;
  late final Size imageSize;

  double get scale => destination.width / source.width;

  /// Un punto de la foto (en fracciones de 0 a 1) en la pantalla.
  Offset toScreen(double fx, double fy) =>
      destination.topLeft +
      (Offset(fx * imageSize.width, fy * imageSize.height) - source.topLeft) *
          scale;

  /// Un punto de la pantalla en fracciones de la foto.
  Offset toPhoto(Offset screen) {
    final p = (screen - destination.topLeft) / scale + source.topLeft;
    return Offset(p.dx / imageSize.width, p.dy / imageSize.height);
  }
}

/// Carga la foto como imagen para dibujarla (una vez por archivo).
class PhotoLoader extends StatefulWidget {
  const PhotoLoader({super.key, required this.file, required this.builder});

  final String file;
  final Widget Function(BuildContext context, ui.Image image) builder;

  @override
  State<PhotoLoader> createState() => _PhotoLoaderState();
}

class _PhotoLoaderState extends State<PhotoLoader> {
  ui.Image? _image;
  String? _loaded;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PhotoLoader old) {
    super.didUpdateWidget(old);
    if (old.file != widget.file) _load();
  }

  Future<void> _load() async {
    final file = widget.file;
    try {
      final bytes = await File(file).readAsBytes();
      final image = await decodeImageFromList(bytes);
      if (!mounted || widget.file != file) return;
      setState(() {
        _image?.dispose();
        _image = image;
        _loaded = file;
      });
    } catch (e) {
      debugPrint('No se pudo abrir la foto: $e');
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null || _loaded == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return widget.builder(context, image);
  }
}

/// La foto del chico, con la boca que se mueve mientras [controller] habla.
class TalkingFace extends StatefulWidget {
  const TalkingFace({
    super.key,
    required this.file,
    required this.photo,
    required this.controller,
  });

  final String file;
  final TalkingPhoto photo;
  final TalkingController controller;

  @override
  State<TalkingFace> createState() => _TalkingFaceState();
}

class _TalkingFaceState extends State<TalkingFace>
    with SingleTickerProviderStateMixin {
  late final AnimationController _frames = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTalk);
    // Cada cuadro avisa qué palabra va (fuera del build, para que la
    // subtitulación se pueda actualizar).
    _frames.addListener(() => widget.controller.tick());
    _onTalk();
  }

  @override
  void didUpdateWidget(TalkingFace old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onTalk);
      widget.controller.addListener(_onTalk);
    }
  }

  /// Mientras habla se redibuja en cada cuadro; callada, la foto queda
  /// quieta (no gasta batería).
  void _onTalk() {
    if (widget.controller.speaking) {
      if (!_frames.isAnimating) _frames.repeat();
    } else {
      _frames.stop();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTalk);
    _frames.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PhotoLoader(
      file: widget.file,
      builder: (context, image) => AnimatedBuilder(
        animation: _frames,
        builder: (context, _) {
          return CustomPaint(
            size: Size.infinite,
            painter: FacePainter(
              image: image,
              photo: widget.photo,
              opening: widget.controller.opening,
            ),
          );
        },
      ),
    );
  }
}

/// Dibuja la foto y, con la boca abierta, baja la parte de abajo de la cara
/// (labio de abajo y mentón) y muestra el interior de la boca, como cuando
/// alguien habla.
class FacePainter extends CustomPainter {
  FacePainter({
    required this.image,
    required this.photo,
    required this.opening,
    this.showMark = false,
  });

  final ui.Image image;
  final TalkingPhoto photo;

  /// 0 cerrada, 1 bien abierta.
  final double opening;

  /// En el editor: marca dónde está la boca.
  final bool showMark;

  @override
  void paint(Canvas canvas, Size size) {
    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final layout = PhotoLayout(imageSize, size);
    final paint = Paint()..filterQuality = FilterQuality.medium;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);
    canvas.drawImageRect(image, layout.source, layout.destination, paint);

    final mouth = layout.toScreen(photo.mouthX, photo.mouthY);
    final width = photo.mouthWidth * imageSize.width * layout.scale;

    if (opening > 0.02) {
      final drop = opening * width * 0.3;

      // El interior de la boca, en el hueco que deja el mentón al bajar.
      final inside = Rect.fromCenter(
        center: mouth + Offset(0, drop / 2),
        width: width * 0.8,
        height: drop + width * 0.08,
      );
      canvas.drawOval(inside, Paint()..color = const Color(0xFF3B0D12));
      if (opening > 0.3) {
        // Un poco de dientes arriba.
        canvas.save();
        canvas.clipPath(Path()..addOval(inside));
        canvas.drawRect(
          Rect.fromLTWH(
            inside.left,
            inside.top,
            inside.width,
            inside.height * 0.22,
          ),
          Paint()..color = const Color(0xFFF2EEE8),
        );
        canvas.restore();
      }

      // El mentón: la parte de la foto debajo de la boca, corrida hacia
      // abajo, con bordes redondeados para que no se note el corte.
      final jawHeight = width * 1.25;
      final jawScreen = Rect.fromLTWH(
        mouth.dx - width * 0.95,
        mouth.dy,
        width * 1.9,
        jawHeight,
      );
      final jawSource = Rect.fromLTRB(
        (jawScreen.left - layout.destination.left) / layout.scale +
            layout.source.left,
        (jawScreen.top - layout.destination.top) / layout.scale +
            layout.source.top,
        (jawScreen.right - layout.destination.left) / layout.scale +
            layout.source.left,
        (jawScreen.bottom - layout.destination.top) / layout.scale +
            layout.source.top,
      );
      final moved = jawScreen.shift(Offset(0, drop));
      canvas.save();
      canvas.clipRRect(
        RRect.fromRectAndCorners(
          moved,
          topLeft: Radius.elliptical(width * 0.5, width * 0.15),
          topRight: Radius.elliptical(width * 0.5, width * 0.15),
          bottomLeft: Radius.elliptical(width * 0.95, jawHeight * 0.7),
          bottomRight: Radius.elliptical(width * 0.95, jawHeight * 0.7),
        ),
      );
      canvas.drawImageRect(image, jawSource, moved, paint);
      canvas.restore();
    }

    if (showMark) {
      final mark = Paint()
        ..color = const Color(0xFF00E5FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawOval(
        Rect.fromCenter(center: mouth, width: width, height: width * 0.45),
        mark,
      );
      canvas.drawLine(
        mouth - Offset(width * 0.6, 0),
        mouth + Offset(width * 0.6, 0),
        mark..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(FacePainter old) =>
      old.opening != opening ||
      old.image != image ||
      old.showMark != showMark ||
      old.photo.mouthX != photo.mouthX ||
      old.photo.mouthY != photo.mouthY ||
      old.photo.mouthWidth != photo.mouthWidth;
}
