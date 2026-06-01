import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/database_helper.dart';

class ReporteHistorialLegalScreen extends StatefulWidget {
  const ReporteHistorialLegalScreen({super.key});

  @override
  State<ReporteHistorialLegalScreen> createState() => _ReporteHistorialLegalScreenState();
}

class _ReporteHistorialLegalScreenState extends State<ReporteHistorialLegalScreen> {
  List<Map<String, dynamic>> _suspensiones = [];
  List<Map<String, dynamic>> _ampliaciones = [];
  List<Map<String, dynamic>> _multas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarHistorialesLegales();
  }

  /// Ejecuta consultas cruzadas SQL combinando las subtablas relacionales
  Future<void> _cargarHistorialesLegales() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper.instance.database;

    // 1. Obtener Historial de Suspensiones con el nombre de su Obra
    final List<Map<String, dynamic>> resSusp = await db.rawQuery('''
      SELECT s.*, p.nombre as proyecto_nombre, p.codigo_contrato 
      FROM suspensiones s
      JOIN proyectos p ON s.proyecto_id = p.id
      ORDER BY s.fecha_suspension DESC
    ''');

    // 2. Obtener Historial de Ampliaciones de tiempo con el nombre de su Obra
    final List<Map<String, dynamic>> resAmp = await db.rawQuery('''
      SELECT a.*, p.nombre as proyecto_nombre, p.codigo_contrato 
      FROM ampliaciones a
      JOIN proyectos p ON a.proyecto_id = p.id
      ORDER BY a.fecha_ampliacion DESC
    ''');

    // 3. Obtener Historial de Multas con el nombre de su Obra
    final List<Map<String, dynamic>> resMultas = await db.rawQuery('''
      SELECT m.*, p.nombre as proyecto_nombre, p.codigo_contrato 
      FROM multas m
      JOIN proyectos p ON m.proyecto_id = p.id
      ORDER BY m.id DESC
    ''');

    if (mounted) {
      setState(() {
        _suspensiones = resSusp;
        _ampliaciones = resAmp;
        _multas = resMultas;
        _isLoading = false;
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
          title: Text("HISTORIAL LEGAL Y CRONOLÓGICO", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          actions: [
            IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _cargarHistorialesLegales),
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.teal,
            tabs: [
              Tab(icon: Icon(Icons.pause_circle_outline, size: 18), text: "Suspensiones"),
              Tab(icon: Icon(Icons.more_time_rounded, size: 18), text: "Ampliaciones"),
              Tab(icon: Icon(Icons.gavel_rounded, size: 18), text: "Multas"),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E293B)))
            : TabBarView(
          children: [
            _buildViewListado(_suspensiones, "suspension"),
            _buildViewListado(_ampliaciones, "ampliacion"),
            _buildViewListado(_multas, "multa"),
          ],
        ),
      ),
    );
  }
  Widget _buildViewListado(List<Map<String, dynamic>> lista, String tipo) {
    if (lista.isEmpty) {
      return Center(
        child: Text(
          "No se registran eventos en esta categoría.",
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.w500),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: lista.length,
      itemBuilder: (context, index) {
        final item = lista[index];
        if (tipo == "suspension") return _cardSuspension(item);
        if (tipo == "ampliacion") return _cardAmpliacion(item);
        return _cardMulta(item);
      },
    );
  }

  Widget _cardSuspension(Map<String, dynamic> s) {
    bool esActiva = s['estado'] == 'SUSPENDIDO';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("CONTRATO: ${s['codigo_contrato'] ?? 'S/N'}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: esActiva ? const Color(0xFF64748B) : const Color(0xFF10B981), borderRadius: BorderRadius.circular(6)),
                child: Text(esActiva ? "SUSPENDIDO" : "ALZADA", style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(s['proyecto_nombre'].toString().toUpperCase(), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
          const Divider(height: 16),
          _itemFilaDetalle("Motivo:", "${s['motivo_suspension']}"),
          _itemFilaDetalle("Fecha Inicio:", "${s['fecha_suspension']}"),
          _itemFilaDetalle("Reactivación:", "${s['fecha_reactivacion'] ?? 'ACTIVA (Sin fecha)'}"),
          _itemFilaDetalle("Días Afectados:", "${s['total_dias_suspendido'] ?? 0} días"),
        ],
      ),
    );
  }

  Widget _cardAmpliacion(Map<String, dynamic> a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("CONTRATO: ${a['codigo_contrato'] ?? 'S/N'}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.teal.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                child: Text("+ ${a['nro_dias_ampliacion']} DÍAS", style: const TextStyle(color: Colors.teal, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(a['proyecto_nombre'].toString().toUpperCase(), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
          const Divider(height: 16),
          _itemFilaDetalle("Justificación:", "${a['motivo_ampliacion']}"),
          _itemFilaDetalle("Fecha Aprobación:", "${a['fecha_ampliacion']}"),
          _itemFilaDetalle("Nueva Fecha Límite:", "${a['fecha_final'] ?? 'No calculada'}"),
        ],
      ),
    );
  }
  Widget _cardMulta(Map<String, dynamic> m) {
    String estado = m['estado'] ?? 'APLICADA';
    Color colorEst = estado == 'PAGADA' ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("CONTRATO: ${m['codigo_contrato'] ?? 'S/N'}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: colorEst, borderRadius: BorderRadius.circular(6)),
                child: Text(estado, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(m['proyecto_nombre'].toString().toUpperCase(), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
          const Divider(height: 16),
          _itemFilaDetalle("Concepto Penalidad:", "${m['motivo_multa']}"),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Monto de Penalización:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                Text(
                    "\$${(m['valor'] as num).toStringAsFixed(2)}",
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFFEF4444))
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemFilaDetalle(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(width: 8),
          Expanded(child: Text(valor, style: const TextStyle(fontSize: 11, color: Color(0xFF334155), height: 1.2))),
        ],
      ),
    );
  }
} // <--- FIN DE LA CLASE STATE DEL REPORTE LEGAL
