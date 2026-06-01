import 'package:flutter/material.dart';
import '../../../data/database_helper.dart';

class RubrosList extends StatelessWidget {
  final int grupoId;
  final int proyectoId;
  final VoidCallback onRefresh;

  const RubrosList({
    super.key,
    required this.grupoId,
    required this.proyectoId,
    required this.onRefresh,
  });

  void _confirmarEliminarHito(BuildContext context, Map<String, dynamic> rubro) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text("Eliminar Rubro")]),
        content: Text("¿Está seguro que desea eliminar el rubro \"${rubro['descripcion']}\"?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await DatabaseHelper.instance.eliminar('hitos', rubro['id'], proyectoId: proyectoId);
              onRefresh();
            },
            child: const Text("ELIMINAR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper.instance.obtenerHitosPorGrupo(grupoId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        return Column(
          children: snapshot.data!.map((rubro) => Column(
            children: [
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                leading: Checkbox(
                  value: rubro['cumplido'] == 1,
                  activeColor: Colors.teal,
                  onChanged: (val) async {
                    await DatabaseHelper.instance.marcarCumplimientoHito(rubro['id'], val! ? 1 : 0, proyectoId);
                    onRefresh();
                  },
                ),
                title: Text(rubro['descripcion'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text("Cant: ${rubro['cantidad']} ${rubro['unidad']} | \$${rubro['precio_unitario']}", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_square, size: 18, color: Colors.blueGrey),
                      onPressed: () => Navigator.pushNamed(context, '/form_hito', arguments: {...rubro, 'proyecto_id': proyectoId}).then((_) => onRefresh()),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.map_rounded, color: Colors.teal, size: 20),
                      onPressed: () => Navigator.pushNamed(context, '/mapa', arguments: rubro['id']),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      onPressed: () => _confirmarEliminarHito(context, rubro),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 0.5, color: Color(0xFFE2E8F0)),
            ],
          )).toList(),
        );
      },
    );
  }
}
