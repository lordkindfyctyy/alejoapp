import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../arasaac.dart';
import '../avisos.dart';
import '../board_store.dart';
import '../models.dart';

/// Ajustes (solo en el modo edición): avisos al celular de papá, registro de lo que dijo Alejo y pictogramas ARASAAC.
class AjustesScreen extends StatefulWidget {
  const AjustesScreen({super.key});

  @override
  State<AjustesScreen> createState() => _AjustesScreenState();
}

class _AjustesScreenState extends State<AjustesScreen> {
  late final TextEditingController _cuidador = TextEditingController(
    text: context.read<Avisos>().cuidador,
  );
  late final TextEditingController _nombre = TextEditingController(
    text: context.read<Avisos>().nombre,
  );
  String? _progreso;
  bool _poniendo = false;

  @override
  void dispose() {
    _cuidador.dispose();
    _nombre.dispose();
    super.dispose();
  }

  /// A cada botón sin foto le pone el primer pictograma de ARASAAC que encuentra para su palabra.
  Future<void> _ponerPictogramas() async {
    final store = context.read<BoardStore>();
    setState(() => _poniendo = true);
    var puestos = 0, sinResultado = 0;
    final pendientes = <(String, Pictogram)>[
      for (final b in [store.home, ...store.categories])
        for (final p in b.items)
          if (p.imagePath == null) (b.id, p),
    ];
    for (var i = 0; i < pendientes.length; i++) {
      final (boardId, p) = pendientes[i];
      setState(
        () => _progreso = '${i + 1} de ${pendientes.length}: ${p.label}',
      );
      try {
        final ids = await Arasaac.buscar(p.label);
        if (ids.isEmpty) {
          sinResultado++;
          continue;
        }
        final f = await Arasaac.descargar(ids.first);
        final img = await store.importMedia(f, 'png');
        await store.savePictogram(
          boardId,
          Pictogram(
            id: p.id,
            label: p.label,
            emoji: p.emoji,
            imagePath: img,
            audioPath: p.audioPath,
          ),
        );
        puestos++;
      } catch (e) {
        setState(
          () => _progreso = 'Se cortó: ¿hay internet? ($puestos puestos)',
        );
        setState(() => _poniendo = false);
        return;
      }
    }
    setState(() {
      _poniendo = false;
      _progreso =
          'Listo: $puestos pictogramas puestos${sinResultado > 0 ? ', $sinResultado palabras sin pictograma (se pueden buscar a mano en el editor)' : ''}.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final avisos = context.watch<Avisos>();
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes y avisos')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '📣 Avisos al celular',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Cuando Alejo pide ayuda, dice que le duele algo o toca "VENÍ", te llega un aviso al celular (y si querés, '
            'cada frase que dice con ▶). Usa ntfy, un servicio gratis y sin cuenta. Este teléfono necesita internet.',
          ),
          SwitchListTile(
            value: avisos.activo,
            onChanged: (v) => avisos.configurar(activo: v),
            title: const Text(
              'Avisos activados',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          SwitchListTile(
            value: avisos.cadaFrase,
            onChanged: (v) => avisos.configurar(cadaFrase: v),
            title: const Text('Avisar también cada frase que dice con ▶'),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cuidador,
                  decoration: const InputDecoration(
                    labelText: 'Quién recibe (PAPÁ, MAMÁ…)',
                  ),
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: (v) => avisos.configurar(cuidador: v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _nombre,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del chico',
                  ),
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: (v) => avisos.configurar(nombre: v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => avisos.configurar(
                cuidador: _cuidador.text,
                nombre: _nombre.text,
              ),
              child: const Text('Guardar nombres'),
            ),
          ),
          Card(
            color: const Color(0xFFFFF8E1),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Para recibirlos en tu celular:',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '1. Instalá la app "ntfy" desde Play Store (es gratis).\n'
                    '2. Tocá  +  y escribí este nombre de canal (dejá el servidor como está, ntfy.sh):',
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    avisos.tema,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .5,
                    ),
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: avisos.tema));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copiado')),
                          );
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copiar'),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            avisos.configurar(temaNuevoAhora: true),
                        icon: const Icon(Icons.autorenew),
                        label: const Text('Cambiar canal'),
                      ),
                    ],
                  ),
                  const Text(
                    '3. Tocá "Probar" acá abajo: te tiene que llegar el aviso.\n'
                    'El nombre del canal funciona como una clave: no lo compartas con quien no quieras que reciba los avisos.',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              FilledButton.icon(
                onPressed: () =>
                    avisos.enviar('Prueba de AlejoApp: ¡los avisos funcionan!'),
                icon: const Icon(Icons.send),
                label: const Text('Probar'),
              ),
              const SizedBox(width: 12),
              if (avisos.ultimoEstado != null)
                Expanded(child: Text(avisos.ultimoEstado!)),
            ],
          ),
          const Divider(height: 36),
          const Text(
            '🗒️ Lo que dijo últimamente',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const Text(
            'Queda guardado solo en este teléfono.',
            style: TextStyle(fontSize: 13),
          ),
          if (avisos.registro.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Todavía nada.'),
            ),
          for (final r in avisos.registro.reversed.take(40))
            ListTile(
              dense: true,
              leading: Icon(
                r['urgente'] != null
                    ? Icons.priority_high
                    : Icons.chat_bubble_outline,
                color: r['urgente'] != null ? Colors.red : null,
              ),
              title: Text(
                r['frase'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(_fecha(r['t'])),
            ),
          const Divider(height: 36),
          const Text(
            '🖼️ Pictogramas ARASAAC',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pone un pictograma de ARASAAC a cada botón que todavía no tiene foto (necesita internet una vez; '
            'después quedan guardados). Cada uno se puede cambiar después en el editor con el botón "Pictograma".',
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _poniendo ? null : _ponerPictogramas,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Poner pictogramas a los botones sin foto'),
          ),
          if (_poniendo)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
            ),
          if (_progreso != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_progreso!),
            ),
          const SizedBox(height: 12),
          const Text(
            Arasaac.autoria,
            style: TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _fecha(String? iso) {
    final d = iso == null ? null : DateTime.tryParse(iso);
    if (d == null) return '';
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(d.day)}/${dos(d.month)} ${dos(d.hour)}:${dos(d.minute)}';
  }
}
