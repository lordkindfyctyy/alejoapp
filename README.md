# AlejoApp

Tablero de comunicación con pictogramas para chicos con autismo (y para
cualquier familia que lo necesite).

- Botones grandes con foto (o emoji) y la palabra en **imprenta mayúscula**.
- Al tocar un botón lo dice en voz alta: con **tu voz grabada** o, si no hay
  grabación, con la voz del teléfono.
- Panel de **Inicio** y panel de **Categorías**: Necesidades, Emociones,
  Personas, Actividades, Lugares y Respuestas (se pueden agregar más).
- **Modo edición** (mantener apretado el candado): agregar, cambiar o borrar
  botones y categorías, subir una foto de la galería o de la cámara,
  recortarla, escribir la palabra y grabar la voz.
- **Barra de palabras clave** siempre a mano: QUIERO, MÁS, NO, AYUDA, TERMINÉ y **PAPÁ VENÍ**.
- **Me siento**: cómo se siente (con cuánto: un poco, bastante, mucho) y **dónde le duele** tocando un cuerpito.
- **Agenda visual**: "primero… después…" y la rutina del día con dibujos; cada paso se marca al terminarlo y se
  resalta lo que sigue.
- **Pictogramas ARASAAC**: buscador dentro del editor y un botón para ponerle pictograma a todos los botones sin foto
  (se descargan una vez y quedan guardados). Autoría: Sergio Palao, ARASAAC (https://arasaac.org), CC BY-NC-SA 4.0,
  Gobierno de Aragón.
- **Avisos al celular de papá** con [ntfy](https://ntfy.sh) (gratis, sin cuenta): cuando pide ayuda, dice que le
  duele algo o toca VENÍ (y, si se quiere, cada frase). Se configura en el modo edición → ⚙️; papá instala la app
  ntfy y se suscribe al canal que muestra la app. Registro de lo que dijo, guardado solo en el teléfono.
- Funciona sin internet y sin cuentas: todo queda guardado en el teléfono (solo los pictogramas ARASAAC y los avisos
  usan internet).

## Desarrollo

```
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```
