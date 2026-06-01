import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/database_helper.dart';

class ResumenProyectosScreen extends StatefulWidget {
  const ResumenProyectosScreen({super.key});

  @override
  State<ResumenProyectosScreen> createState() => _ResumenProyectosScreenState();
}

class _ResumenProyectosScreenState extends State<ResumenProyectosScreen> {
  List<Map<String, dynamic>> _reporteProyectos = [];
  List<Map<String, dynamic>> _proyectosFiltrados = []; // Nueva lista para el motor de búsqueda
  bool _isLoading = true;

  // --- CONTROLADORES DE BÚSQUEDA SUPERIOR ---
  final _searchCtrl = TextEditingController();
  String _filtroBusqueda = "";

  @override
  void initState() {
    super.initState();
    _cargarReporteConsolidado();
  }

  /// Procesa la base de datos offline analizando alertas avanzadas por cada obra
  Future<void> _cargarReporteConsolidated() async {
    // Alias preventivo por consistencia interna
    await _cargarReporteConsolidado();
  }

  Future<void> _cargarReporteConsolidado() async {
    setState(() => _isLoading = true);
    final dbHelper = DatabaseHelper.instance;
    final db = await dbHelper.database;

    final List<Map<String, dynamic>> proyectosRaw = await db.query('proyectos', orderBy: 'nombre ASC');
    List<Map<String, dynamic>> reporteProcesado = [];

    for (var p in proyectosRaw) {
      int proyId = p['id'] as int;

      final List<Map<String, dynamic>> suspActivas = await db.query(
        'suspensiones',
        where: 'proyecto_id = ? AND estado = ?',
        whereArgs: [proyId, 'SUSPENDIDO'],
      );

      final List<Map<String, dynamic>> multasActivas = await db.query(
        'multas',
        where: 'proyecto_id = ? AND estado = ?',
        whereArgs: [proyId, 'APLICADA'],
      );

      String alertaEstadoCalculado = "EN EJECUCION";

      if (p['alerta_atraso'] == 1) {
        alertaEstadoCalculado = "RETRASADO";
      }
      if (multasActivas.isNotEmpty) {
        alertaEstadoCalculado = "CON MULTAS";
      }
      if (suspActivas.isNotEmpty) {
        alertaEstadoCalculado = "SUSPENDIDO";
      }

      reporteProcesado.add({
        ...p,
        'alerta_estado': alertaEstadoCalculado,
        'es_subproyecto': p['proyecto_padre_id'] != null,
      });
    }

    if (mounted) {
      setState(() {
        _reporteProyectos = reporteProcesado;
        _aplicarFiltroBusqueda(); // Aplica el filtro inicial
        _isLoading = false;
      });
    }
  }

  /// Aplica el filtro en tiempo real basándose en lo ingresado en el buscador superior
  void _aplicarFiltroBusqueda() {
    if (_filtroBusqueda.isEmpty) {
      _proyectosFiltrados = List.from(_reporteProyectos);
    } else {
      _proyectosFiltrados = _reporteProyectos.where((proy) {
        final String nombreObra = (proy['nombre'] ?? '').toString().toLowerCase();
        return nombreObra.contains(_filtroBusqueda.toLowerCase());
      }).toList();
    }
  }
  Future<void> _abrirEnlaceSercop(String? urlStr) async {
    if (urlStr == null || urlStr.trim().isEmpty) {
      _notificar("⚠️ No se encuentra registrada una URL SERCOP para esta obra.");
      return;
    }
    final Uri url = Uri.parse(urlStr.trim());
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _notificar("❌ No se pudo abrir el navegador para la URL proporcionada.");
      }
    } catch (e) {
      _notificar("❌ Enlace inválido o corrupto.");
    }
  }

  void _notificar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text("REPORTE EJECUTIVO DE OBRAS", style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _cargarReporteConsolidado,
          )
        ],
      ),
      body: Column(
        children: [
          // --- NUEVO COMPONENTE: BARRA SUPERIOR DE BÚSQUEDA ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: "Buscar obra en el resumen ejecutivo...",
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                suffixIcon: _filtroBusqueda.isNotEmpty
                    ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() { _filtroBusqueda = ""; _aplicarFiltroBusqueda(); });
                    }
                )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade200)),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (val) {
                setState(() {
                  _filtroBusqueda = val.trim();
                  _aplicarFiltroBusqueda();
                });
              },
            ),
          ),

          // LISTADO FILTRADO PROGRESIVO
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E293B)))
                : _proyectosFiltrados.isEmpty
                ? const Center(child: Text("No se encontraron obras coincidentes."))
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _proyectosFiltrados.length,
              itemBuilder: (context, index) {
                return _buildCardResumenFicha(_proyectosFiltrados[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildCardResumenFicha(Map<String, dynamic> proy) {
    bool esSub = proy['es_subproyecto'];
    String estado = proy['alerta_estado'];

    Color colorAlerta;
    switch (estado) {
      case "SUSPENDIDO":
        colorAlerta = const Color(0xFF64748B);
        break;
      case "CON MULTAS":
        colorAlerta = const Color(0xFFF59E0B);
        break;
      case "RETRASADO":
        colorAlerta = const Color(0xFFEF4444);
        break;
      default:
        colorAlerta = const Color(0xFF10B981);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: esSub ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      esSub ? Icons.subdirectory_arrow_right_rounded : Icons.corporate_fare_rounded,
                      size: 16,
                      color: esSub ? Colors.blueGrey : const Color(0xFF1E293B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      esSub ? "SUBOBRA / SUBPROYECTO" : "PROYECTO MATRIZ",
                      style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.blueGrey, letterSpacing: 0.5),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: colorAlerta, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    estado,
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              proy['nombre'].toString().toUpperCase(),
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B), height: 1.3),
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Divider(height: 1, thickness: 0.5)),

            _filaTextoResumen("Código Contrato:", "${proy['codigo_contrato'] ?? 'S/N'}"),
            _filaTextoResumen("Fiscalizador:", "${proy['fiscalizador'] ?? 'S/N'}"),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(15)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _celdaFinanciera("MONTO POA", (proy['monto_total'] as num).toDouble()),
                  _celdaFinanciera("DEVENGADO", (proy['presupuesto_devengado'] as num).toDouble()),
                  _celdaFinanciera("SALDO", (proy['saldo'] as num).toDouble()),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF1E293B)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.language_rounded, size: 16, color: Color(0xFF1E293B)),
                    label: const Text("PROCESO SERCOP", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                    onPressed: () => _abrirEnlaceSercop(proy['url_sercop']),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.map_rounded, size: 16, color: Colors.white),
                    label: const Text("VER GIS MAPA", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                    onPressed: () => Navigator.pushNamed(context, '/mapa', arguments: proy['id']),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _filaTextoResumen(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(width: 6),
          Expanded(child: Text(valor, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF334155)))),
        ],
      ),
    );
  }

  Widget _celdaFinanciera(String label, double valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 2),
        Text("\$${valor.toStringAsFixed(2)}", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
      ],
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose(); // Destrucción higiénica del controlador de búsqueda
    super.dispose();
  }
}
