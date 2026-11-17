/// Un pictograma: una foto (o un emoji si todavía no tiene foto), la palabra
/// en imprenta mayúscula y, opcionalmente, una grabación de voz propia.
class Pictogram {
  Pictogram({
    required this.id,
    required this.label,
    this.emoji = '',
    this.imagePath,
    this.audioPath,
  });

  final String id;
  String label;
  String emoji;

  /// Rutas relativas a la carpeta de medios de la app (ver BoardStore).
  String? imagePath;
  String? audioPath;

  factory Pictogram.fromJson(Map<String, dynamic> json) => Pictogram(
    id: json['id'] as String,
    label: json['label'] as String? ?? '',
    emoji: json['emoji'] as String? ?? '',
    imagePath: json['imagePath'] as String?,
    audioPath: json['audioPath'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'emoji': emoji,
    if (imagePath != null) 'imagePath': imagePath,
    if (audioPath != null) 'audioPath': audioPath,
  };
}

/// Un tablero de pictogramas. "Inicio" es el tablero principal; el resto son
/// las categorías (Necesidades, Emociones, ...), que también se pueden
/// editar, agregar o borrar.
class Board {
  Board({
    required this.id,
    required this.name,
    this.emoji = '',
    this.imagePath,
    List<Pictogram>? items,
  }) : items = items ?? [];

  final String id;
  String name;
  String emoji;
  String? imagePath;
  final List<Pictogram> items;

  factory Board.fromJson(Map<String, dynamic> json) => Board(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    emoji: json['emoji'] as String? ?? '',
    imagePath: json['imagePath'] as String?,
    items: [
      for (final item in json['items'] as List? ?? const [])
        Pictogram.fromJson(Map<String, dynamic>.from(item as Map)),
    ],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    if (imagePath != null) 'imagePath': imagePath,
    'items': [for (final item in items) item.toJson()],
  };
}
