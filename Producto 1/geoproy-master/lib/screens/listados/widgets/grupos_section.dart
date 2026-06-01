import 'package:flutter/material.dart';
import '../../../data/database_helper.dart';
import 'rubros_list.dart';

class GruposSection extends StatelessWidget {
  final int proyectoId;
  final VoidCallback onRefresh;

  const GruposSection({super.key, required this.proyectoId, required this.onRefresh});

  void _dialogGrupo(BuildContext context, {Map<String, dynamic>? existing}) {
    final c = TextEditingController(text: existing != null ? existing['nombre'] : "");
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? "Nuevo Capítulo" : "Editar Capítulo"),
        content: TextField(controller: c, decoration: const InputDecoration(hintText: "Nombre")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
          ElevatedButton(
            onPressed: () async {
              if (c.text.trim().isEmpty) return;
              final db = await DatabaseHelper.instance.database;
              if (existing == null) {
                await db.insert('hitos_grupos', {'proyecto_id': proyectoId, 'nombre': c.text.trim().toUpperCase()});
              } else {
                await db.update('hitos_grupos', {'nombre': c.text.trim().toUpperCase()}, where: 'id = ?', whereArgs: [existing['id']]);
              }
              Navigator.pop(ctx);
              onRefresh();
            },
            child: const Text("GUARDAR"),
          ),
        ],
      ),
    );
  }

  void _confirmarEliminarGrupo(BuildContext context, Map<String, dynamic> grupo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text("Eliminar Capítulo")]),
        content: Text("¿Está seguro que desea eliminar el capítulo \"${grupo['nombre']}\"? Se perderán sus rubros anidados."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await DatabaseHelper.instance.eliminar('hitos_grupos', grupo['id'], proyectoId: proyectoId);
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
      future: DatabaseHelper.instance.obtenerGruposPorProyecto(proyectoId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        return Column(
          children: snapshot.data!.map((g) => Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: const Color(0xFFE2E8F0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        g['nombre'].toString().toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Color(0xFF334155)),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.edit, size: 16, color: Color(0xFF334155)),
                          onPressed: () => _dialogGrupo(context, existing: g),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.add_circle, size: 18, color: Color(0xFF1E293B)),
                          onPressed: () => Navigator.pushNamed(context, '/form_hito', arguments: {'grupo_id': g['id'], 'proyecto_id': proyectoId}).then((_) => onRefresh()),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                          onPressed: () => _confirmarEliminarGrupo(context, g),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              RubrosList(grupoId: g['id'], proyectoId: proyectoId, onRefresh: onRefresh),
            ],
          )).toList(),
        );
      },
    );
  }
}
