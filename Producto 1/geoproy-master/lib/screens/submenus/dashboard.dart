import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:sqflite/sqflite.dart';
import '../../data/database_helper.dart';
import '../../data/pdf_service.dart';
import '../../data/excel_export_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Métricas Financieras
  double totalPOA = 0.0, totalDevengado = 0.0, saldoGlobal = 0.0;

  // Métricas de Riesgo y Prioridad
  int obrasAltaPrioridad = 0, obrasAtrasadas = 0, obrasFinalizadas = 0;

  // Inventario Multimedia
  int totalFotos = 0, totalAudios = 0;

  List<FinancialData> chartData = [];
  List<RiskData> riskData = [];

  @override
  void initState() {
    super.initState();
    _procesarInteligencia();
  }

  /// Procesa toda la data de la DB Maestra V14 para las gráficas y métricas
  void _procesarInteligencia() async {
    final db = DatabaseHelper.instance;
    final proyectos = await db.obtenerProyectos();
    final database = await db.database;

    double sumaPOA = 0, sumaDev = 0;
    int altaRiesgo = 0, altaOK = 0, mediaRiesgo = 0, mediaOK = 0, bajaRiesgo = 0, bajaOK = 0, fin = 0;
    List<FinancialData> tempChart = [];

    for (var p in proyectos) {
      double poa = (p['monto_total'] as num).toDouble();
      double dev = (p['presupuesto_devengado'] as num).toDouble();
      sumaPOA += poa;
      sumaDev += dev;

      if (p['porcentaje_avance'] >= 100) fin++;

      // Clasificación de Riesgo por Prioridad y Alerta de Atraso
      if (p['prioridad'] == 'ALTA') {
        p['alerta_atraso'] == 1 ? altaRiesgo++ : altaOK++;
      } else if (p['prioridad'] == 'MEDIA') {
        p['alerta_atraso'] == 1 ? mediaRiesgo++ : mediaOK++;
      } else {
        p['alerta_atraso'] == 1 ? bajaRiesgo++ : bajaOK++;
      }

      tempChart.add(FinancialData(
          p['nombre'].toString().length > 10 ? p['nombre'].toString().substring(0, 10) + "..." : p['nombre'],
          poa, dev
      ));
    }

    var resMedia = await database.rawQuery('''
      SELECT 
        (SELECT COUNT(*) FROM hitos WHERE fotografia IS NOT NULL) + 
        (SELECT COUNT(*) FROM geografias WHERE fotografia IS NOT NULL) as f,
        (SELECT COUNT(*) FROM geografias WHERE audio IS NOT NULL) as a
    ''');

    setState(() {
      totalPOA = sumaPOA;
      totalDevengado = sumaDev;
      saldoGlobal = sumaPOA - sumaDev;
      obrasFinalizadas = fin;
      obrasAtrasadas = altaRiesgo + mediaRiesgo + bajaRiesgo;
      obrasAltaPrioridad = altaRiesgo + altaOK;
      totalFotos = (resMedia.first['f'] as int?) ?? 0;
      totalAudios = (resMedia.first['a'] as int?) ?? 0;
      chartData = tempChart;
      riskData = [
        RiskData('ALTA', altaRiesgo, altaOK),
        RiskData('MEDIA', mediaRiesgo, mediaOK),
        RiskData('BAJA', bajaRiesgo, bajaOK),
      ];
    });
  }

  // --- LÓGICA DE EXPORTACIÓN ADAPTADA CON SELECCIÓN DE PROYECTO ---
  Future<void> _handleExport(bool isWhatsapp) async {
    // 1. Obtener la lista de todos los proyectos de la base de datos para el selector
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> todosLosProyectos = await db.query('proyectos', orderBy: 'nombre ASC');

    if (todosLosProyectos.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("⚠️ No existen proyectos en el sistema para exportar."),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    int? proyectoSeleccionadoId;

    // 2. Desplegar el diálogo interactivo para elegir la obra específica
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Seleccione el Proyecto a Exportar:", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: todosLosProyectos.length,
            itemBuilder: (c, i) => ListTile(
              leading: const Icon(Icons.analytics_rounded, color: Color(0xFF1E293B)),
              title: Text(todosLosProyectos[i]['nombre'].toString().toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              subtitle: Text("Contrato: ${todosLosProyectos[i]['codigo_contrato'] ?? 'S/N'}", style: const TextStyle(fontSize: 10)),
              onTap: () {
                proyectoSeleccionadoId = todosLosProyectos[i]['id'];
                Navigator.pop(ctx); // Cierra el modal capturando el ID
              },
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("CANCELAR", style: TextStyle(color: Colors.grey))
          ),
        ],
      ),
    );

    // 3. Escape de nulidad y promoción de tipo segura para Dart
    if (proyectoSeleccionadoId == null) return;
    final int idSeleccionado = proyectoSeleccionadoId!;

    // 4. Mostrar SnackBar de carga nativa contextualizada
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isWhatsapp ? "📲 Preparando reporte para WhatsApp..." : "📂 Generando archivo Excel consolidado..."),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    // 5. Invocar el motor de exportación pasando el ID de la obra seleccionada
    try {
      await ExcelExportService.exportarTodoElPortafolio(idSeleccionado);
    } catch (e) {
      // Reemplaza _msg por el SnackBar nativo si '_msg' no está definido en este componente
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error en exportación: $e"), behavior: SnackBarBehavior.floating)
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text("Panel de Control", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.2)),
        actions: [
          IconButton(
              tooltip: "Reporte PDF",
              icon: const Icon(Icons.picture_as_pdf_rounded),
              onPressed: () async => PdfService.exportarReporte(await DatabaseHelper.instance.obtenerProyectos())
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFinancialHeader(),
            const SizedBox(height: 20),
            _buildStatusSummary(),
            const SizedBox(height: 25),
            _buildChartSection("Riesgo Crítico por Prioridad", _buildRiskChart()),
            const SizedBox(height: 25),
            _buildChartSection("Planificado vs. Ejecutado", _buildFinancialChart()),
            const SizedBox(height: 25),
            _buildMultimediaInfo(),
            const SizedBox(height: 30),

            // --- BOTONES DE EXPORTACIÓN CORREGIDOS ---
            /*
            _buildExportButton(
                "DESCARGAR PORTAFOLIO EXCEL",
                const Color(0xFF10B981),
                Icons.download_for_offline_rounded,
                    () => _handleExport(false)
            ),
            const SizedBox(height: 12),
            */
            _buildExportButton(
                "Compartir Reporte",
                const Color(0xFF25D366),
                Icons.share_rounded,
                    () => _handleExport(true)
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS DE DISEÑO ---

  Widget _buildFinancialHeader() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(35),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _moneyColumn("TOTAL POA", totalPOA, Colors.white),
              _moneyColumn("EJECUTADO", totalDevengado, Colors.cyanAccent),
            ],
          ),
          const Divider(color: Colors.white10, height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("SALDO DISPONIBLE", style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
              Text("\$${saldoGlobal.toStringAsFixed(2)}",
                  style: GoogleFonts.poppins(color: Colors.orangeAccent, fontWeight: FontWeight.w900, fontSize: 20)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStatusSummary() {
    return Row(
      children: [
        _statusCard("Críticos", obrasAtrasadas.toString(), Colors.redAccent),
        const SizedBox(width: 10),
        _statusCard("Alta Prioridad", obrasAltaPrioridad.toString(), Colors.orangeAccent),
        const SizedBox(width: 10),
        _statusCard("Finalizados", obrasFinalizadas.toString(), Colors.tealAccent),
      ],
    );
  }

  Widget _buildChartSection(String title, Widget chart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.blueGrey)),
        const SizedBox(height: 10),
        Container(
          height: 250,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
          child: chart,
        ),
      ],
    );
  }

  Widget _buildRiskChart() {
    return SfCartesianChart(
      primaryXAxis: CategoryAxis(),
      legend: Legend(isVisible: true, position: LegendPosition.bottom),
      series: <CartesianSeries>[
        StackedColumnSeries<RiskData, String>(
          name: 'Retraso', dataSource: riskData, xValueMapper: (d, _) => d.prioridad, yValueMapper: (d, _) => d.atrasados,
          color: Colors.red.shade400, borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
        ),
        StackedColumnSeries<RiskData, String>(
          name: 'A tiempo', dataSource: riskData, xValueMapper: (d, _) => d.prioridad, yValueMapper: (d, _) => d.aTiempo,
          color: const Color(0xFF1E293B), borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
        ),
      ],
    );
  }

  Widget _buildFinancialChart() {
    return SfCartesianChart(
      primaryXAxis: CategoryAxis(),
      series: <CartesianSeries>[
        ColumnSeries<FinancialData, String>(
          name: 'POA', dataSource: chartData, xValueMapper: (d, _) => d.name, yValueMapper: (d, _) => d.poa,
          color: Colors.grey.shade300,
        ),
        ColumnSeries<FinancialData, String>(
          name: 'Ejecución', dataSource: chartData, xValueMapper: (d, _) => d.name, yValueMapper: (d, _) => d.dev,
          color: Colors.indigoAccent,
        ),
      ],
    );
  }

  Widget _buildMultimediaInfo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _badgeMedia(Icons.camera_alt_rounded, "$totalFotos Fotos", Colors.blue),
        _badgeMedia(Icons.mic_rounded, "$totalAudios Audios", Colors.purple),
      ],
    );
  }

  Widget _buildExportButton(String label, Color color, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 15),
            Text(label, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // --- AUXILIARES ---
  Widget _moneyColumn(String l, double v, Color c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(l, style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
    Text("\$${v.toStringAsFixed(0)}", style: TextStyle(color: c, fontSize: 20, fontWeight: FontWeight.w900))
  ]);

  Widget _statusCard(String l, String v, Color c) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)),
      child: Column(children: [
        Text(v, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: c)),
        Text(l, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey)),
      ]),
    ),
  );

  Widget _badgeMedia(IconData i, String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
    child: Row(children: [Icon(i, size: 16, color: c), const SizedBox(width: 8), Text(t, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 11))]),
  );

  void _msg(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t), behavior: SnackBarBehavior.floating));
}

class FinancialData { FinancialData(this.name, this.poa, this.dev); final String name; final double poa; final double dev; }
class RiskData { RiskData(this.prioridad, this.atrasados, this.aTiempo); final String prioridad; final int atrasados; final int aTiempo; }
