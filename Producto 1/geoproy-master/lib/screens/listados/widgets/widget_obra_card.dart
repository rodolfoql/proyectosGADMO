import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import '../../../data/database_helper.dart';

class WidgetObraCard extends StatelessWidget {
  final Map<String, dynamic> proyecto;
  final VoidCallback onRefreshRequired;

  const WidgetObraCard({
    super.key,
    required this.proyecto,
    required this.onRefreshRequired,
  });

  @override
  Widget build(BuildContext context) {
    final int proyectoId = proyecto['id'] as int;
    final bool enPeligro = proyecto['alerta_atraso'] == 1;
    final bool tieneHijos = proyecto['tiene_hijos'] ?? false;
    final bool esSubproyecto = proyecto['proyecto_padre_id'] != null;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: esSubproyecto ? 0 : 15, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: enPeligro ? Border.all(color: Colors.red.shade400, width: 2) : Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: esSubproyecto ? null : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: ExpansionTile(
        key: PageStorageKey('proy_$proyectoId'),
        backgroundColor: esSubproyecto ? const Color(0xFFF8FAFC) : Colors.white,

        // =====================================================================
        // MODIFICACIÓN COMPLETA: INSIGNIA INTELIGENTE CON INTERACTIVIDAD MULTI-ESTADO
        // =====================================================================

        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // Alinea  a la izquierda
          //crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,                // Ocupa solo el espacio necesario
          children: [
            SizedBox(
              width: double.infinity,
              child: Text(
                //proyecto['nombre'].toString().toUpperCase(),
                proyecto['nombre'].toString(),
                textAlign: TextAlign.justify, // ◄ JUSTIFICA EL TEXTO (Izquierda y Derecha)
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w800,
                  fontSize: esSubproyecto ? 11 : 12,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ),
            const SizedBox(height: 8), // Espacio vertical entre el texto y la insignia

            // --- CONSOLA DE INSIGNIA INTERACTIVA (BADGE MULTI-ESTADO GADMO) ---
            (() {
              final String estadoActual = proyecto['estado_proyecto'] ?? 'EN EJECUCION';
              final bool estaSuspendido = estadoActual == 'SUSPENDIDO';
              final bool estaFinalizado = estadoActual == 'FINALIZADO';

              // 1. Asignación de Textos del Semáforo de Control
              String textoMostrar = tieneHijos
                  ? "PROYECTO PADRE"
                  : (esSubproyecto ? "SUBOBRA" : "INDEPENDIENTE");

              if (estaSuspendido) {
                textoMostrar = "SUSPENDIDO";
              } else if (estaFinalizado) {
                textoMostrar = "FINALIZADO";
              }

              // 2. Asignación Cromática de Estados Contractuales
              Color colorBadge;
              if (estaSuspendido) {
                colorBadge = const Color(0xFFEF4444); // Rojo detención
              } else if (estaFinalizado) {
                colorBadge = const Color(0xFF1E293B); // Azul Marino / Pizarra Profundo Cierre
              } else if (tieneHijos) {
                colorBadge = const Color(0xFF0284C7); // Azul matrices
              } else if (esSubproyecto) {
                colorBadge = const Color(0xFF06B6D4); // Cian subobras
              } else {
                colorBadge = const Color(0xFF64748B); // Gris independientes
              }

              return GestureDetector(
                onTap: estaSuspendido
                    ? () => _mostrarDialogoAlzadoRapido(proyecto, context)
                    : (estaFinalizado || tieneHijos ? null : () => _confirmarFinalizacionManualObra(proyecto, context)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorBadge,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: (estaSuspendido || estaFinalizado) ? [
                      BoxShadow(color: colorBadge.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))
                    ] : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min, // La insignia mantiene su diseño interno horizontal
                    children: [
                      if (estaSuspendido) ...[
                        const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 10),
                        const SizedBox(width: 3),
                      ] else if (estaFinalizado) ...[
                        const Icon(Icons.verified_rounded, color: Colors.white, size: 10),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        textoMostrar,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            })(),
          ],
        ),


        /*title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                  proyecto['nombre'].toString().toUpperCase(),
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      fontSize: esSubproyecto ? 11 : 12,
                      color: const Color(0xFF1E293B)
                  )
              ),
            ),
            const SizedBox(width: 8),

            // --- CONSOLA DE INSIGNIA INTERACTIVA (BADGE MULTI-ESTADO GADMO) ---
            (() {
              final String estadoActual = proyecto['estado_proyecto'] ?? 'EN EJECUCION';
              final bool estaSuspendido = estadoActual == 'SUSPENDIDO';
              final bool estaFinalizado = estadoActual == 'FINALIZADO';

              // 1. Asignación de Textos del Semáforo de Control
              String textoMostrar = tieneHijos
                  ? "PROYECTO PADRE"
                  : (esSubproyecto ? "SUBOBRA" : "INDEPENDIENTE");

              if (estaSuspendido) {
                textoMostrar = "SUSPENDIDO";
              } else if (estaFinalizado) {
                textoMostrar = "FINALIZADO";
              }

              // 2. Asignación Cromática de Estados Contractuales
              Color colorBadge;
              if (estaSuspendido) {
                colorBadge = const Color(0xFFEF4444); // Rojo detención
              } else if (estaFinalizado) {
                colorBadge = const Color(0xFF1E293B); // Azul Marino / Pizarra Profundo Cierre
              } else if (tieneHijos) {
                colorBadge = const Color(0xFF0284C7); // Azul matrices
              } else if (esSubproyecto) {
                colorBadge = const Color(0xFF06B6D4); // Cian subobras
              } else {
                colorBadge = const Color(0xFF64748B); // Gris independientes
              }

              return GestureDetector(
                // ENRUTADOR TÁCTIL INTELIGENTE DE INSIGNIAS:
                // Si está suspendido abre el calendario rápido; si está activo permite finalizar manualmente.
                onTap: estaSuspendido
                    ? () => _mostrarDialogoAlzadoRapido(proyecto, context)
                    : (estaFinalizado || tieneHijos ? null : () => _confirmarFinalizacionManualObra(proyecto, context)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorBadge,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: (estaSuspendido || estaFinalizado) ? [
                      BoxShadow(color: colorBadge.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))
                    ] : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (estaSuspendido) ...[
                        const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 10),
                        const SizedBox(width: 3),
                      ] else if (estaFinalizado) ...[
                        const Icon(Icons.verified_rounded, color: Colors.white, size: 10),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        textoMostrar,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5
                        ),
                      ),
                    ],
                  ),
                ),
              );
            })(),
          ],
        ),
        */

        /*
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                  proyecto['nombre'].toString().toUpperCase(),
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      fontSize: esSubproyecto ? 11 : 12,
                      color: const Color(0xFF1E293B)
                  )
              ),
            ),
            const SizedBox(width: 8),

            // --- CONSOLA DE INSIGNIA INTERACTIVA (BADGE GADMO) ---
            (() {
              final String estadoActual = proyecto['estado_proyecto'] ?? 'EN EJECUCION';
              final bool estaSuspendido = estadoActual == 'SUSPENDIDO';

              String textoMostrar = tieneHijos
                  ? "PROYECTO PADRE"
                  : (esSubproyecto ? "SUBOBRA" : "INDEPENDIENTE");

              if (estaSuspendido) {
                textoMostrar = "SUSPENDIDO";
              }

              Color colorBadge;
              if (estaSuspendido) {
                colorBadge = const Color(0xFFEF4444); // Rojo detención
              } else if (tieneHijos) {
                colorBadge = const Color(0xFF0284C7); // Azul matrices
              } else if (esSubproyecto) {
                colorBadge = const Color(0xFF06B6D4); // Cian subobras
              } else {
                colorBadge = const Color(0xFF64748B); // Gris independientes
              }

              return GestureDetector(
                onTap: estaSuspendido
                    ? () => _mostrarDialogoAlzadoRapido(proyecto, context)
                    : null, // Solo es clickeable si la obra está suspendida
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorBadge,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: estaSuspendido ? [
                      BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))
                    ] : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (estaSuspendido) ...[
                        const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 10),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        textoMostrar,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5
                        ),
                      ),
                    ],
                  ),
                ),
              );
            })(),
          ],
        ),
        */
        subtitle: _buildStatusHeader(proyecto),
        children: [
          // RECURSIVIDAD EN CASCADA: Si la obra tiene hijos, se vuelve a invocar a sí misma anidada
          if (tieneHijos) _buildSubproyectosSection(proyectoId, context),

          _buildFinancialAuditPanel(proyecto),
          _buildProjectActions(proyecto, context),
          _buildGruposSection(proyectoId, context),
          const SizedBox(height: 15),
        ],
      ),
    );
  }

  Widget _buildStatusHeader(Map<String, dynamic> p) {
    bool danger = p['alerta_atraso'] == 1;
    bool tieneHijos = p['tiene_hijos'] ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 5),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: danger ? Colors.red : Colors.teal, borderRadius: BorderRadius.circular(8)),
            child: Text(danger ? "⚠️ RETRASADO" : "✅ A TIEMPO", style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Text(tieneHijos ? "Avance Ponderado: ${p['porcentaje_avance'].toInt()}%" : "Avance Técnico: ${p['porcentaje_avance'].toInt()}%", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
        ]),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: (p['porcentaje_avance'] as double) / 100,
          minHeight: 5, color: danger ? Colors.red : Colors.teal,
          backgroundColor: Colors.grey.shade200,
        ),
      ],
    );
  }
  Widget _buildFinancialAuditPanel(Map<String, dynamic> p) {
    bool tieneHijos = p['tiene_hijos'] ?? false;
    String plazoMostrar = tieneHijos ? "${p['plazo_dinamico'] ?? 0} " : "${p['plazo_dinamico'] ?? p['plazo'] ?? 0} d";

    return Container(
      padding: const EdgeInsets.all(15), color: const Color(0xFFF1F5F9),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _metric("MONTO", "\$${p['monto_total'].toStringAsFixed(0)}"),
        _metric("DEVENGADO", "\$${p['presupuesto_devengado'].toStringAsFixed(0)}"),
        _metric("SALDO", "\$${p['saldo'].toStringAsFixed(0)}"),
        _metric("PLAZO(dias)", plazoMostrar),
      ]),
    );
  }

  Widget _metric(String l, String v) => Column(children: [
    Text(l, style: const TextStyle(fontSize: 8, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
    Text(v, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)))
  ]);

  Widget _buildProjectActions(Map<String, dynamic> p, BuildContext context) {
    final bool tieneHijos = p['tiene_hijos'] ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // VALIDACIÓN: Oculta el botón si es un Proyecto Padre
          if (!tieneHijos) ...[
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: const Color(0xFF1E293B), padding: const EdgeInsets.all(12)),
              icon: const Icon(Icons.create_new_folder_rounded, color: Colors.white, size: 22),
              tooltip: "Agregar Capítulo",
              onPressed: () => _dialogGrupo(p['id'], context),
            ),
          ],

          // ===================================================================
          // EL BOTÓN DEL MAZO/GAVEL TEAL INTEGRADO SIN RECHAZOS SINTÁCTICOS
          // ===================================================================
          if (!tieneHijos)
          IconButton.filledTonal(
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFE6F4F1),
              padding: const EdgeInsets.all(12),
            ),
            icon: const Icon(Icons.gavel_rounded, color: Color(0xFF00A884), size: 22),
            tooltip: "Gestión Legal, Suspensiones y Multas",
            onPressed: () {
              Navigator.pushNamed(context, '/gestion_tiempos', arguments: p)
                  .then((_) => onRefreshRequired());
            },
          ),
          // ===================================================================

          IconButton.filledTonal(
            style: IconButton.styleFrom(backgroundColor: const Color(0xFFEFF6FF), padding: const EdgeInsets.all(12)),
            icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF2563EB), size: 22),
            tooltip: "Editar Proyecto",
            onPressed: () => Navigator.pushNamed(context, '/form_proyecto', arguments: p).then((_) => onRefreshRequired()),
          ),

          IconButton.filledTonal(
            style: IconButton.styleFrom(backgroundColor: const Color(0xFFFEF2F2), padding: const EdgeInsets.all(12)),
            icon: Icon(Icons.delete_forever_rounded, color: Colors.red.shade800, size: 22),
            tooltip: "Eliminar Registro",
            onPressed: () => _confirmarEliminarProyecto(p, context),
          )
        ],
      ),
    );
  }

  Widget _buildSubproyectosSection(int proyectoPadreId, BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper.instance.database.then((db) => db.query(
          'proyectos',
          where: 'proyecto_padre_id = ?',
          whereArgs: [proyectoPadreId],
          orderBy: 'nombre ASC'
      )),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox();

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10, left: 16, right: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F9FF),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xFFBAE6FD)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Text(
                  "PROYECTOS ASOCIADOS:",
                  style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w900, color: const Color(0xFF0369A1), letterSpacing: 0.5),
                ),
              ),
              Column(
                children: snapshot.data!.map((subproy) {
                  return WidgetObraCard(
                    proyecto: subproy,
                    onRefreshRequired: onRefreshRequired,
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
  Widget _buildGruposSection(int proyectoId, BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper.instance.obtenerGruposPorProyecto(proyectoId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        return Column(
          children: snapshot.data!.map((g) => Column(children: [
            Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFE2E8F0),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(child: Text(g['nombre'].toString().toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Color(0xFF334155)))),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(), icon: const Icon(Icons.edit, size: 16, color: Color(0xFF334155)), onPressed: () => _dialogGrupo(proyectoId, context, existing: g)),
                  const SizedBox(width: 12),
                  IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(), icon: const Icon(Icons.add_circle, size: 18, color: Color(0xFF1E293B)),
                      onPressed: () => Navigator.pushNamed(context, '/form_hito', arguments: {'grupo_id': g['id'], 'proyecto_id': proyectoId}).then((_) => onRefreshRequired())),
                  const SizedBox(width: 12),
                  IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(), icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18), onPressed: () => _confirmarEliminarGrupo(g, proyectoId, context)),
                ]),
              ]),
            ),
            _buildRubrosList(g['id'], proyectoId, context),
          ])).toList(),
        );
      },
    );
  }

  Widget _buildRubrosList(int grupoId, int proyectoId, BuildContext context) {
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
                    onRefreshRequired();
                  },
                ),
                title: Text(rubro['descripcion'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text("Cant: ${rubro['cantidad']} ${rubro['unidad']} | \$${rubro['precio_unitario']}", style: TextStyle(fontSize: 11, color: Colors.grey.shade600))),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(icon: const Icon(Icons.edit_square, size: 18, color: Colors.blueGrey), onPressed: () => Navigator.pushNamed(context, '/form_hito', arguments: {...rubro, 'proyecto_id': proyectoId}).then((_) => onRefreshRequired())),
                    const SizedBox(width: 16),
                    IconButton(icon: const Icon(Icons.map_rounded, color: Colors.teal, size: 20), onPressed: () => Navigator.pushNamed(context, '/mapa', arguments: rubro['id'])),
                    const SizedBox(width: 16),
                    IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => _confirmarEliminarHito(rubro, proyectoId, context)),
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

  // --- CONSOLA FLOTANTE AUTOMATIZADA MULTI-SUSPENSIONES HISTÓRICAS ---
  void _mostrarDialogoAlzadoRapido(Map<String, dynamic> proy, BuildContext context) async {
    final int proyectoId = proy['id'] as int;
    final db = await DatabaseHelper.instance.database;
    final fechaCtrl = TextEditingController();

    // Filtra de forma descendente aislando estrictamente la última detención sin cerrar
    final List<Map<String, dynamic>> ultimaSuspActiva = await db.query(
        'suspensiones',
        where: 'proyecto_id = ? AND estado = ? AND fecha_reactivacion IS NULL',
        whereArgs: [proyectoId, 'SUSPENDIDO'],
        orderBy: 'id DESC',
        limit: 1
    );

    if (ultimaSuspActiva.isEmpty) {
      debugPrint("No se hallaron suspensiones abiertas para procesar.");
      return;
    }

    final int suspensionId = ultimaSuspActiva.first['id'] as int;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.event_available_rounded, color: Color(0xFF10B981)),
            const SizedBox(width: 8),
            Text("Reactivar Cronograma", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "PROYECTO: ${proy['nombre'].toString().toUpperCase()}",
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
            const SizedBox(height: 8),
            const Text(
              "Establezca la fecha de finalización de esta paralización para reactivar las alertas del POA.",
              style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.3),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: fechaCtrl,
              readOnly: true,
              decoration: InputDecoration(
                labelText: "Fecha de Reactivación (Fin)",
                prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onTap: () async {
                DateTime? picked = await showDatePicker(
                  context: ctx,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2101),
                );
                if (picked != null) {
                  fechaCtrl.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () async {
              if (fechaCtrl.text.isEmpty) return;
              Navigator.pop(ctx);

              // 1. Inyecta la fecha fin a la celda relacional abierta en SQLite
              await db.update(
                  'suspensiones',
                  {
                    'fecha_reactivacion': fechaCtrl.text,
                    'estado': 'SUSPENCION FINALIZADA'
                  },
                  where: 'id = ?',
                  whereArgs: [suspensionId]
              );

              // ===============================================================
              // AUTOMATIZACIÓN COMPLETA: Cambia el estado del proyecto al alzar
              // ===============================================================
              await db.update(
                'proyectos',
                {'estado_proyecto': 'EN EJECUCION'},
                where: 'id = ?',
                whereArgs: [proyectoId],
              );
              // ===============================================================

              // Gatillo de auditoría: Recalcula días de prórroga contractualmente
              await DatabaseHelper.instance.auditarProyecto(proyectoId);
              onRefreshRequired();
            },
            child: const Text("CONCLUIR SUSPENSIÓN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }


  /*
  void _mostrarDialogoAlzadoRapido(Map<String, dynamic> proy, BuildContext context) async {
    final int proyectoId = proy['id'] as int;
    final db = await DatabaseHelper.instance.database;
    final fechaCtrl = TextEditingController();

    final List<Map<String, dynamic>> ultimaSuspActiva = await db.query(
        'suspensiones',
        where: 'proyecto_id = ? AND estado = ? AND fecha_reactivacion IS NULL',
        whereArgs: [proyectoId, 'SUSPENDIDO'],
        orderBy: 'id DESC',
        limit: 1
    );

    if (ultimaSuspActiva.isEmpty) {
      debugPrint("No se hallaron suspensiones abiertas para procesar.");
      return;
    }

    final int suspensionId = ultimaSuspActiva.first['id'] as int;
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.event_available_rounded, color: Color(0xFF10B981)),
            const SizedBox(width: 8),
            Text("Reactivar Cronograma", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "PROYECTO: ${proy['nombre'].toString().toUpperCase()}",
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
            const SizedBox(height: 8),
            const Text(
              "Establezca la fecha de finalización de esta paralización para reactivar las alertas del POA.",
              style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.3),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: fechaCtrl,
              readOnly: true,
              decoration: InputDecoration(
                labelText: "Fecha de Reactivación (Fin)",
                prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onTap: () async {
                DateTime? picked = await showDatePicker(
                  context: ctx,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2101),
                );
                if (picked != null) {
                  fechaCtrl.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () async {
              if (fechaCtrl.text.isEmpty) return;
              Navigator.pop(ctx);

              await db.update(
                  'suspensiones',
                  {'fecha_reactivacion': fechaCtrl.text, 'estado': 'SUSPENCION FINALIZADA'},
                  where: 'id = ?',
                  whereArgs: [suspensionId]
              );

              await DatabaseHelper.instance.auditarProyecto(proyectoId);
              onRefreshRequired();
            },
            child: const Text("CONCLUIR SUSPENSIÓN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
  */
  void _dialogGrupo(int pId, BuildContext context, {Map<String, dynamic>? existing}) {
    final c = TextEditingController(text: existing != null ? existing['nombre'] : "");
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(existing == null ? "Nuevo Capítulo" : "Editar Capítulo"),
      content: TextField(controller: c, decoration: const InputDecoration(hintText: "Nombre")),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
        ElevatedButton(onPressed: () async {
          if (existing == null) {
            await DatabaseHelper.instance.insertarGrupo({'proyecto_id': pId, 'nombre': c.text});
          } else {
            final db = await DatabaseHelper.instance.database;
            await db.update('hitos_grupos', {'nombre': c.text}, where: 'id = ?', whereArgs: [existing['id']]);
          }
          Navigator.pop(ctx); onRefreshRequired();
        }, child: const Text("GUARDAR")),
      ],
    ));
  }

  void _confirmarEliminarProyecto(Map<String, dynamic> p, BuildContext context) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text("Eliminar Registro")]),
      content: Text("¿Está seguro que desea eliminar \"${p['nombre']}\"? Se perderán irreversiblemente todos sus capítulos, subproyectos y rubros anidados."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR", style: TextStyle(color: Colors.grey))),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () async {
          Navigator.pop(ctx); final db = await DatabaseHelper.instance.database; int? padreId = p['proyecto_padre_id'];
          await db.delete('proyectos', where: 'id = ?', whereArgs: [p['id']]);
          if (padreId != null) await DatabaseHelper.instance.auditarProyecto(padreId);
          onRefreshRequired();
        }, child: const Text("ELIMINAR", style: TextStyle(color: Colors.white)))
      ],
    ));
  }

  void _confirmarEliminarHito(Map<String, dynamic> rubro, int proyectoId, BuildContext context) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Eliminar Rubro"), content: Text("¿Desea eliminar el rubro \"${rubro['descripcion']}\"?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () async {
          Navigator.pop(ctx); await DatabaseHelper.instance.eliminar('hitos', rubro['id'], proyectoId: proyectoId); onRefreshRequired();
        }, child: const Text("ELIMINAR", style: TextStyle(color: Colors.white)))
      ],
    ));
  }

  void _confirmarEliminarGrupo(Map<String, dynamic> grupo, int proyectoId, BuildContext context) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Eliminar Capítulo"), content: Text("¿Desea eliminar el capítulo \"${grupo['nombre']}\"?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () async {
          Navigator.pop(ctx); await DatabaseHelper.instance.eliminar('hitos_grupos', grupo['id'], proyectoId: proyectoId); onRefreshRequired();
        }, child: const Text("ELIMINAR", style: TextStyle(color: Colors.white)))
      ],
    ));
  }


  // --- CONSOLA FLOTANTE: DETERMINACIÓN Y CLAUSURA MANUAL DE OBRA FINALIZADA ---
  void _confirmarFinalizacionManualObra(dynamic proy, BuildContext context) {
  // Alias preventivo por si el mapa se transfiere con tipos dinámicos
  _confirmarFinalizacionManualObraEspecifico(proy as Map<String, dynamic>, context);
  }

  void _confirmarFinalizacionManualObraEspecifico(Map<String, dynamic> proy, BuildContext context) {
  final int proyectoId = proy['id'] as int;

  showDialog(
  context: context,
  builder: (ctx) => AlertDialog(
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  title: Row(
  children: [
  const Icon(Icons.verified_rounded, color: Color(0xFF1E293B)),
  const SizedBox(width: 8),
  Text("Finalizar Obra", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold)),
  ],
  ),
  content: Text(
  "¿Está seguro que desea declarar la obra \"${proy['nombre'].toString().toUpperCase()}\" como FINALIZADA?\n\nEsta acción registrará la entrega técnico-administrativa y sellará el estado actual de las planillas.",
  style: const TextStyle(fontSize: 11, color: Color(0xFF334155), height: 1.3),
  ),
  actions: [
  TextButton(
  onPressed: () => Navigator.pop(ctx),
  child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)),
  ),
  ElevatedButton(
  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
  onPressed: () async {
  Navigator.pop(ctx);
  final db = await DatabaseHelper.instance.database;

  // 1. Mutación forzada manual a estado definitivo de cierre
  await db.update(
  'proyectos',
  {'estado_proyecto': 'FINALIZADO'},
  where: 'id = ?',
  whereArgs: [proyectoId],
  );

  // 2. Ejecutar auditoría masiva para congelar balances finales
  await DatabaseHelper.instance.auditarProyecto(proyectoId);

  // 3. Forzar refresco reactivo de la UI del portafolio
  onRefreshRequired();
  },
  child: const Text("SÍ, FINALIZAR OBRA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
  ),
  ],
  ),
  );
  }



} // <--- CUBRE Y CIERRA EL FINAL ABSOLUTO DE TU CLASE WIDGETOBRACARD
