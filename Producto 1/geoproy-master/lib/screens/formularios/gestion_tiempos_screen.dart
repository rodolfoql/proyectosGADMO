import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/database_helper.dart';

class GestionTiemposScreen extends StatefulWidget {
  final dynamic arguments;
  const GestionTiemposScreen({super.key, this.arguments});

  @override
  State<GestionTiemposScreen> createState() => _GestionTiemposScreenState();
}

// CORRECCIÓN: Nombre de clase alineado exactamente con el generador del estado
class _GestionTiemposScreenState extends State<GestionTiemposScreen> {
  final _formKeySuspension = GlobalKey<FormState>();
  final _formKeyAmpliacion = GlobalKey<FormState>();
  final _formKeyMulta = GlobalKey<FormState>();

  int _proyectoId = 0;
  String _nombreProyecto = "Cargando Obra...";

  // --- CONTROLADORES DE SUSPENSIONES ---
  final _motivoSuspCtrl = TextEditingController();
  final _fechaSuspCtrl = TextEditingController();
  final _fechaReactCtrl = TextEditingController();
  String _estadoSuspension = 'SUSPENDIDO';

  int? _suspensionEdicionId;

  // --- CONTROLADORES DE AMPLIACIONES ---
  final _motivoAmpCtrl = TextEditingController();
  final _fechaAmpCtrl = TextEditingController();
  final _diasAmpCtrl = TextEditingController();

  // --- CONTROLADORES DE MULTAS ---
  final _motivoMultaCtrl = TextEditingController();
  final _valorMultaCtrl = TextEditingController();
  String _estadoMulta = 'APLICADA';



  @override
  void initState() {
    super.initState();
    _procesarArgumentos();
  }

  void _procesarArgumentos() {
    final args = widget.arguments;
    if (args is Map<String, dynamic>) {
      _proyectoId = args['id'] ?? 0;
      _nombreProyecto = (args['nombre'] ?? "Obra Municipal").toString().toUpperCase();
    }
  }

  Future<void> _seleccionarFecha(BuildContext context, TextEditingController controller) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        controller.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text("Control de la Obra", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w800)),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.teal,
            tabs: [
              Tab(icon: Icon(Icons.pause_circle_outline, size: 20), text: "Suspensiones"),
              Tab(icon: Icon(Icons.add_moderator, size: 20), text: "Ampliaciones"),
              Tab(icon: Icon(Icons.money_off, size: 20), text: "Multas"),
            ],
          ),
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: const Color(0xFFE2E8F0),
              child: Text(
                "OBRA: $_nombreProyecto",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Color(0xFF334155)),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildPanelSuspensiones(),
                  _buildPanelAmpliaciones(),
                  _buildPanelMultas(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  // --- PANEL DE CONTROL DE SUSPENSIONES CON RECONOCIMIENTO AUTOMÁTICO DE ESTADOS ---
  Widget _buildPanelSuspensiones() {
    return Form(
      key: _formKeySuspension,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _sectionHeader(_suspensionEdicionId == null ? "Registrar Evento de Suspensión" : "Cerrar / Alzar Suspensión Activa"),
          _input(_motivoSuspCtrl, "Motivo / Justificación Legal de la Suspensión", Icons.description, required: true, maxLines: 2),
          Row(children: [
            Expanded(child: _input(_fechaSuspCtrl, "Fecha Suspensión", Icons.calendar_today, required: true, isDate: true)),
            const SizedBox(width: 10),
            Expanded(child: _input(_fechaReactCtrl, "Fecha Reactivación / Fin", Icons.event_available, required: false, isDate: true)),
          ]),
          const SizedBox(height: 15),

          // --- BOTÓN MAESTRO DE ACCIÓN CON CONEXIÓN REACTIVA ---
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            ),
            icon: const Icon(Icons.save, color: Colors.white),
            label: Text(
                _suspensionEdicionId == null ? "GUARDAR SUSPENSIÓN" : "ACTUALIZAR Y ALZAR SUSPENSIÓN",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
            ),
            onPressed: () async {
              if (_formKeySuspension.currentState!.validate()) {
                final db = await DatabaseHelper.instance.database;

                // AUTOMATIZACIÓN DE ESTADOS: Si el fiscalizador ingresa fecha de reactivación,
                // el sistema asume que la suspensión se levanta y la obra se reanuda de inmediato.
                String estadoCalculado = _fechaReactCtrl.text.isNotEmpty ? 'SUSPENCION FINALIZADA' : 'SUSPENDIDO';

                Map<String, dynamic> datos = {
                  'motivo_suspension': _motivoSuspCtrl.text.trim(),
                  'fecha_suspension': _fechaSuspCtrl.text,
                  'fecha_reactivacion': _fechaReactCtrl.text.isEmpty ? null : _fechaReactCtrl.text,
                  'estado': estadoCalculado,
                };

                if (_suspensionEdicionId != null) {
                  // CASO EDICIÓN DESDE EL HISTORIAL
                  await db.update('suspensiones', datos, where: 'id = ?', whereArgs: [_suspensionEdicionId]);
                  if (_fechaReactCtrl.text.isNotEmpty) {
                    // Si se alza la suspensión, restauramos el estado base a la fila del proyecto
                    await db.update('proyectos', {'estado_proyecto': 'EN EJECUCION'}, where: 'id = ?', whereArgs: [_proyectoId]);
                  }
                } else {
                  // CASO NUEVO: Invoca la inserción blindada del helper mutando la columna 'estado_proyecto'
                  await DatabaseHelper.instance.insertarSuspension(datos, _proyectoId);
                }

                // Gatillo de consolidación masiva: Recalcula plazos y saldo en el Proyecto Padre
                await DatabaseHelper.instance.auditarProyecto(_proyectoId);

                setState(() { _suspensionEdicionId = null; });
                _limpiarFormularios();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("✅ Estado contractual actualizado en disco."), behavior: SnackBarBehavior.floating)
                  );

                  // RETORNO CLAVE: Devuelve 'true' al portafolio para forzar el re-renderizado
                  // instantáneo de la insignia a color ROJO o CIAN sin necesidad de reiniciar la app.
                  Navigator.pop(context, true);
                }
              }
            },
          ),

          const SizedBox(height: 25),
          _sectionHeader("Historial de Suspensiones de esta Obra"),

          // --- VISOR DE HISTORIAL INTEGRADO PARA EDICIONES EN CALIENTE ---
          FutureBuilder<List<Map<String, dynamic>>>(
            future: DatabaseHelper.instance.database.then((db) => db.query(
                'suspensiones',
                where: 'proyecto_id = ?',
                whereArgs: [_proyectoId],
                orderBy: 'id DESC'
            )),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text("No se registran eventos previos.", style: TextStyle(fontSize: 11, color: Colors.grey));
              }
              return Column(
                children: snapshot.data!.map((s) {
                  bool esActiva = s['estado'] == 'SUSPENDIDO';
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      dense: true,
                      title: Text(
                          "Estado: ${s['estado']}",
                          style: TextStyle(fontWeight: FontWeight.bold, color: esActiva ? Colors.red : Colors.teal)
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          "Inicio: ${s['fecha_suspension']} | Fin: ${s['fecha_reactivacion'] ?? 'Activa'}\n"
                              "Motivo: ${s['motivo_suspension']}\n"
                              "⏱️ Días Suspendidos: ${s['total_dias_suspendido'] ?? 0} días", // <-- EXTRACCIÓN DIRECTA DEL CAMPO
                          style: const TextStyle(fontSize: 11, height: 1.3),
                        ),
                      ),

                      /*
                      subtitle: Text(
                          "Inicio: ${s['fecha_suspension']} | Fin: ${s['fecha_reactivacion'] ?? 'Activa'}\nMotivo: ${s['motivo_suspension']}",
                          style: const TextStyle(fontSize: 11)
                      ),
                      */
                      trailing: esActiva
                          ? IconButton(
                        icon: const Icon(Icons.edit_calendar_rounded, color: Colors.indigo),
                        onPressed: () {
                          // Al pulsar el lápiz del historial, cargamos los datos en los inputs superiores para completarlos
                          setState(() {
                            _suspensionEdicionId = s['id'];
                            _motivoSuspCtrl.text = s['motivo_suspension'] ?? '';
                            _fechaSuspCtrl.text = s['fecha_suspension'] ?? '';
                            _fechaReactCtrl.text = ''; // Dejamos libre la caja para la fecha de finalización
                          });
                        },
                      )
                          : null,
                    ),
                  );
                }).toList(),
              );
            },
          )
        ],
      ),
    );
  }



  /*
  Widget _buildPanelSuspensiones() {
    return Form(
      key: _formKeySuspension,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _sectionHeader("Registrar Evento de Suspensión"),
          _input(_motivoSuspCtrl, "Motivo / Justificación Legal de la Suspensión", Icons.description, required: true, maxLines: 2),
          Row(children: [
            Expanded(child: _input(_fechaSuspCtrl, "Fecha Suspensión", Icons.calendar_today, required: true, isDate: true)),
            const SizedBox(width: 10),
            Expanded(child: _input(_fechaReactCtrl, "Fecha Reactivación (Opcional)", Icons.event_available, required: false, isDate: true)),
          ]),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: DropdownButtonFormField<String>(
              value: _estadoSuspension,
              decoration: InputDecoration(labelText: "Estado de la Suspensión", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.rule_folder)),
              items: const [
                DropdownMenuItem(value: 'SUSPENDIDO', child: Text("SUSPENDIDO")),
                DropdownMenuItem(value: 'SUSPENCION FINALIZADA', child: Text("ALZAR SUSPENSIÓN")),
              ],
              onChanged: (v) => setState(() => _estadoSuspension = v!),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text("GUARDAR SUSPENSIÓN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () async {
              if (_formKeySuspension.currentState!.validate()) {
                await DatabaseHelper.instance.insertarSuspension({
                  'motivo_suspension': _motivoSuspCtrl.text.trim(),
                  'fecha_suspension': _fechaSuspCtrl.text,
                  'fecha_reactivacion': _fechaReactCtrl.text.isEmpty ? null : _fechaReactCtrl.text,
                  'estado': _estadoSuspension,
                }, _proyectoId);
                _limpiarFormularios();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Suspensión aplicada. Plazos actualizados."), behavior: SnackBarBehavior.floating));
              }
            },
          ),
        ],
      ),
    );
  }
  */


  Widget _buildPanelAmpliaciones() {
    return Form(
      key: _formKeyAmpliacion,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _sectionHeader("REGISTRAR AMPLIACIÓN DE PLAZO CONTRACTUAL"),
          _input(_motivoAmpCtrl, "Motivo / Adendum de Justificación", Icons.description, required: true, maxLines: 2),
          Row(children: [
            Expanded(child: _input(_fechaAmpCtrl, "Fecha de Aprobación", Icons.calendar_today, required: true, isDate: true)),
            const SizedBox(width: 10),
            Expanded(child: _input(_diasAmpCtrl, "Número de Días a Otorgar", Icons.more_time_rounded, isNum: true, required: true)),
          ]),
          const SizedBox(height: 15),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            ),
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text("GUARDAR AMPLIACIÓN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () async {
              if (_formKeyAmpliacion.currentState!.validate()) {
                final db = await DatabaseHelper.instance.database;

                await db.insert('ampliaciones', {
                  'proyecto_id': _proyectoId,
                  'motivo_ampliacion': _motivoAmpCtrl.text.trim(),
                  'fecha_ampliacion': _fechaAmpCtrl.text,
                  'nro_dias_ampliacion': int.parse(_diasAmpCtrl.text),
                });

                // Forzamos el recálculo inmediato de los nuevos plazos consolidados
                await DatabaseHelper.instance.auditarProyecto(_proyectoId);
                _limpiarFormularios();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("✅ Ampliación guardada y días sumados al cronograma."), behavior: SnackBarBehavior.floating)
                  );
                  Navigator.pop(context, true); // Retorna confirmación de refresco al portafolio
                }
              }
            },
          ),

          // ===================================================================
          // INTEGRACIÓN: HISTORIAL DE AMPLIACIONES DE PLAZO CONTRACTUAL
          // ===================================================================
          const SizedBox(height: 25),
          _sectionHeader("HISTORIAL DE AMPLIACIONES DE ESTA OBRA"),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: DatabaseHelper.instance.database.then((db) => db.query(
                'ampliaciones',
                where: 'proyecto_id = ?',
                whereArgs: [_proyectoId],
                orderBy: 'id DESC'
            )),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text("No se registran ampliaciones de plazo en el adendum.", style: TextStyle(fontSize: 11, color: Colors.grey)),
                );
              }
              return Column(
                children: snapshot.data!.map((a) {
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))   ),
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.history_toggle_off_rounded, color: Colors.teal),
                      title: Text(
                          "Plazo Otorgado: +${a['nro_dias_ampliacion']} Días",
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11, color: const Color(0xFF1E293B))
                      ),
                      subtitle: Text(
                          "Aprobación: ${a['fecha_ampliacion']}\nJustificación: ${a['motivo_ampliacion']}",
                          style: const TextStyle(fontSize: 11, height: 1.3)
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          )
          // ===================================================================
        ],
      ),
    );
  }


  /*
  Widget _buildPanelAmpliaciones() {
    return Form(
      key: _formKeyAmpliacion,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _sectionHeader("Registrar Ampliación de Plazo Contractual"),
          _input(_motivoAmpCtrl, "Motivo / Adendum de Ampliación de Tiempo", Icons.assignment, required: true, maxLines: 2),
          Row(children: [
            Expanded(child: _input(_fechaAmpCtrl, "Fecha de Aprobación", Icons.calendar_today, required: true, isDate: true)),
            const SizedBox(width: 10),
            Expanded(child: _input(_diasAmpCtrl, "Número de Días Otorgados", Icons.more_time, required: true, isNum: true)),
          ]),
          const SizedBox(height: 15),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text("GUARDAR AMPLIACIÓN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () async {
              if (_formKeyAmpliacion.currentState!.validate()) {
                await DatabaseHelper.instance.insertarAmpliacion({
                  'motivo_ampliacion': _motivoAmpCtrl.text.trim(),
                  'fecha_ampliacion': _fechaAmpCtrl.text,
                  'nro_dias_ampliacion': int.parse(_diasAmpCtrl.text),
                }, _proyectoId);
                _limpiarFormularios();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Ampliación inyectada al cronograma con éxito."), behavior: SnackBarBehavior.floating));
              }
            },
          ),
        ],
      ),
    );
  }
  */

  Widget _buildPanelMultas() {
    return Form(
      key: _formKeyMulta,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _sectionHeader("REGISTRAR MULTA"),
          _input(_motivoMultaCtrl, "Concepto / Incumplimiento Contractual", Icons.gavel_rounded, required: true, maxLines: 2),
          _input(_valorMultaCtrl, "Valor Económico de la Sanción (\$)", Icons.monetization_on_outlined, isNum: true, required: true),
          const SizedBox(height: 15),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            ),
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text("GUARDAR MULTA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () async {
              if (_formKeyMulta.currentState!.validate()) {
                final db = await DatabaseHelper.instance.database;

                await db.insert('multas', {
                  'proyecto_id': _proyectoId,
                  'motivo_multa': _motivoMultaCtrl.text.trim(),
                  'valor': double.parse(_valorMultaCtrl.text),
                  'estado': 'APLICADA',
                });

                // Re-audita el semáforo para pintar en ámbar el listado de saldos consolidados
                await DatabaseHelper.instance.auditarProyecto(_proyectoId);
                _limpiarFormularios();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("⚠️ Sanción económica aplicada con éxito."), behavior: SnackBarBehavior.floating)
                  );
                  Navigator.pop(context, true);
                }
              }
            },
          ),

          // ===================================================================
          // INTEGRACIÓN: HISTORIAL DE PENALIZACIONES Y MULTAS FINANCIERAS
          // ===================================================================
          const SizedBox(height: 25),
          _sectionHeader("HISTORIAL DE MULTAS DE ESTA OBRA"),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: DatabaseHelper.instance.database.then((db) => db.query(
                'multas',
                where: 'proyecto_id = ?',
                whereArgs: [_proyectoId],
                orderBy: 'id DESC'
            )),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text("No se registran penalizaciones o multas económicas cargadas.", style: TextStyle(fontSize: 11, color: Colors.grey)),
                );
              }
              return Column(
                children: snapshot.data!.map((m) {
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))  ),
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.gavel_rounded, color: Colors.redAccent),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Sanción: ${m['estado']}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.red.shade800)),
                          Text(
                              "\$${(m['valor'] as num).toStringAsFixed(2)}",
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.red.shade900)
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text("Concepto: ${m['motivo_multa']}", style: const TextStyle(fontSize: 11, height: 1.2)),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          )
          // ===================================================================
        ],
      ),
    );
  }


  /*
  Widget _buildPanelMultas() {
    return Form(
      key: _formKeyMulta,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _sectionHeader("Registrar Multa / Penalización Contratista"),
          _input(_motivoMultaCtrl, "Concepto / Incumplimiento Contractual de la Multa", Icons.gavel, required: true, maxLines: 2),
          _input(_valorMultaCtrl, "Valor Económico de la Penalidad (\$)", Icons.monetization_on, required: true, isNum: true),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: DropdownButtonFormField<String>(
              value: _estadoMulta,
              decoration: InputDecoration(labelText: "Estado Inicial Multa", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.fact_check)),
              items: const [
                DropdownMenuItem(value: 'APLICADA', child: Text("APLICADA")),
                DropdownMenuItem(value: 'APELADA', child: Text("APELADA")),
                DropdownMenuItem(value: 'PAGADA', child: Text("PAGADA")),
              ],
              onChanged: (v) => setState(() => _estadoMulta = v!),
            ),
          ),
          const SizedBox(height: 15),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text("GUARDAR MULTA APLICADA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () async {
              if (_formKeyMulta.currentState!.validate()) {
                await DatabaseHelper.instance.insertarMulta({
                  'motivo_multa': _motivoMultaCtrl.text.trim(),
                  'valor': double.parse(_valorMultaCtrl.text),
                  'estado': _estadoMulta,
                }, _proyectoId);
                _limpiarFormularios();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠️ Penalización registrada de forma permanente."), behavior: SnackBarBehavior.floating));
              }
            },
          ),
        ],
      ),
    );
  }
  */

  // --- COMPONENTES AUXILIARES DEL CORE DE INTERFAZ ---
  Widget _sectionHeader(String t) => Padding(padding: const EdgeInsets.only(top: 5, bottom: 16), child: Text(t.toUpperCase(), style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.blueGrey)));

  Widget _input(TextEditingController c, String l, IconData i, {bool isNum = false, bool isDate = false, int maxLines = 1, required bool required}) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
        controller: c,
        maxLines: maxLines,
        readOnly: isDate,
        onTap: isDate ? () => _seleccionarFecha(context, c) : null,
        keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        decoration: InputDecoration(
          labelText: l,
          prefixIcon: Icon(i, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: isDate,
          fillColor: isDate ? const Color(0xFFF1F5F9) : null,
        ),
        validator: (v) {
          if (required && (v == null || v.trim().isEmpty)) return "Obligatorio";
          if (isNum && v != null && v.isNotEmpty && double.tryParse(v) == null) return "Número inválido";
          return null;
        }
    ),
  );

  void _limpiarFormularios() {
    setState(() {
      _motivoSuspCtrl.clear(); _fechaSuspCtrl.clear(); _fechaReactCtrl.clear();
      _motivoAmpCtrl.clear(); _fechaAmpCtrl.clear(); _diasAmpCtrl.clear();
      _motivoMultaCtrl.clear(); _valorMultaCtrl.clear();
    });
  }

  @override
  void dispose() {
    _motivoSuspCtrl.dispose(); _fechaSuspCtrl.dispose(); _fechaReactCtrl.dispose();
    _motivoAmpCtrl.dispose(); _fechaAmpCtrl.dispose(); _diasAmpCtrl.dispose();
    _motivoMultaCtrl.dispose(); _valorMultaCtrl.dispose();
    super.dispose();
  }
}
