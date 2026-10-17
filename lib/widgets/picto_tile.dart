import 'dart:io';

import 'package:flutter/material.dart';

/// Tarjeta grande con la foto (o el emoji) arriba y la palabra en imprenta
/// mayúscula abajo. Se usa para los pictogramas y para las categorías.
class PictoTile extends StatefulWidget {
  const PictoTile({
    super.key,
    required this.label,
    required this.emoji,
    required this.imageFile,
    required this.onTap,
    this.editing = false,
    this.hasVoice = false,
    this.color,
  });

  final String label;
  final String emoji;

  /// Ruta completa de la foto, o null.
  final String? imageFile;
  final VoidCallback onTap;

  /// En modo edición se marca con un lápiz.
  final bool editing;

  /// Tiene una grabación de voz propia.
  final bool hasVoice;
  final Color? color;

  @override
  State<PictoTile> createState() => _PictoTileState();
}

class _PictoTileState extends State<PictoTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final image = widget.imageFile;
    return Semantics(
      button: true,
      label: widget.label,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1,
        duration: const Duration(milliseconds: 90),
        child: Material(
          color: widget.color ?? scheme.surfaceContainerLowest,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: widget.editing ? scheme.primary : scheme.outlineVariant,
              width: widget.editing ? 3 : 1.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (v) => setState(() => _pressed = v),
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                        child: image != null && File(image).existsSync()
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  File(image),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  // Al reemplazar la foto se guarda con otro
                                  // nombre, así que no hace falta invalidar
                                  // la caché.
                                  cacheWidth: 400,
                                ),
                              )
                            : FittedBox(
                                child: Text(
                                  widget.emoji.isEmpty ? '❔' : widget.emoji,
                                  style: const TextStyle(fontSize: 64),
                                ),
                              ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                      child: SizedBox(
                        height: 30,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            widget.label.toUpperCase(),
                            maxLines: 1,
                            textScaler: TextScaler.noScaling,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.hasVoice)
                  const Positioned(
                    top: 6,
                    left: 6,
                    child: _Badge(icon: Icons.mic),
                  ),
                if (widget.editing)
                  const Positioned(
                    top: 6,
                    right: 6,
                    child: _Badge(icon: Icons.edit),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 14,
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: Icon(icon, size: 16, color: Colors.white),
    );
  }
}

/// Tarjeta "+" para agregar en modo edición.
class AddTile extends StatelessWidget {
  const AddTile({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle, size: 56, color: scheme.primary),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grilla que acomoda tarjetas de ~170 px según el ancho del teléfono.
const kTileGrid = SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 180,
  mainAxisSpacing: 12,
  crossAxisSpacing: 12,
  childAspectRatio: 0.82,
);
