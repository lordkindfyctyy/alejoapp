import 'models.dart';

/// Id del tablero principal. No aparece en la lista de categorías.
const String kHomeBoardId = 'inicio';

/// Tableros con los que arranca la app la primera vez. Todo se puede editar:
/// cambiar la palabra, poner una foto propia o grabar la voz.
List<Board> defaultBoards() {
  var n = 0;
  List<Pictogram> items(List<(String, String)> list) => [
        for (final (emoji, label) in list)
          Pictogram(id: 'p${n++}', label: label, emoji: emoji),
      ];

  return [
    Board(id: kHomeBoardId, name: 'INICIO', emoji: '⭐', items: items([
      ('🏠', 'CASA'),
      ('💧', 'AGUA'),
      ('🍽️', 'COMER'),
      ('🚽', 'BAÑO'),
      ('👍', 'SÍ'),
      ('👎', 'NO'),
      ('🙋', 'AYUDA'),
      ('➕', 'MÁS'),
      ('✅', 'TERMINÉ'),
      ('😴', 'DORMIR'),
    ])),
    Board(id: 'necesidades', name: 'NECESIDADES', emoji: '🙋', items: items([
      ('🍽️', 'COMER'),
      ('💧', 'TOMAR AGUA'),
      ('🚽', 'BAÑO'),
      ('😴', 'DORMIR'),
      ('🙋', 'AYUDA'),
      ('🤕', 'ME DUELE'),
      ('🥶', 'TENGO FRÍO'),
      ('🥵', 'TENGO CALOR'),
    ])),
    Board(id: 'emociones', name: 'EMOCIONES', emoji: '😀', items: items([
      ('😀', 'FELIZ'),
      ('😢', 'TRISTE'),
      ('😠', 'ENOJADO'),
      ('😨', 'MIEDO'),
      ('😩', 'CANSADO'),
      ('😬', 'NERVIOSO'),
      ('😮', 'SORPRENDIDO'),
      ('😌', 'TRANQUILO'),
    ])),
    Board(id: 'personas', name: 'PERSONAS', emoji: '👨‍👩‍👦', items: items([
      ('👩', 'MAMÁ'),
      ('👨', 'PAPÁ'),
      ('🧒', 'YO'),
      ('👦', 'HERMANO'),
      ('👵', 'ABUELA'),
      ('👴', 'ABUELO'),
      ('🧑‍🏫', 'MAESTRA'),
      ('🧑‍🤝‍🧑', 'AMIGO'),
    ])),
    Board(id: 'actividades', name: 'ACTIVIDADES', emoji: '🧸', items: items([
      ('🧸', 'JUGAR'),
      ('🖍️', 'DIBUJAR'),
      ('🎵', 'MÚSICA'),
      ('📺', 'TELE'),
      ('📱', 'TABLET'),
      ('🚶', 'PASEAR'),
      ('📖', 'LEER'),
      ('🛁', 'BAÑARME'),
    ])),
    Board(id: 'lugares', name: 'LUGARES', emoji: '📍', items: items([
      ('🏠', 'CASA'),
      ('🏫', 'ESCUELA'),
      ('🛝', 'PLAZA'),
      ('🚗', 'AUTO'),
      ('🛒', 'SUPERMERCADO'),
      ('🏥', 'DOCTOR'),
      ('🌳', 'PARQUE'),
      ('🛏️', 'CAMA'),
    ])),
    Board(id: 'respuestas', name: 'RESPUESTAS', emoji: '💬', items: items([
      ('👍', 'SÍ'),
      ('👎', 'NO'),
      ('🤷', 'NO SÉ'),
      ('✋', 'ESPERÁ'),
      ('🛑', 'BASTA'),
      ('🔁', 'OTRA VEZ'),
      ('🙏', 'GRACIAS'),
      ('👋', 'HOLA'),
      ('👋', 'CHAU'),
    ])),
  ];
}
