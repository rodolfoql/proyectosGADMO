import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PdfService {
  /// Genera y muestra un PDF con el resumen ejecutivo de los proyectos
  static Future<void> exportarReporte(List<Map<String, dynamic>> data) async {
    final pdf = pw.Document();
    final fechaActual = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("CONSTRUCT PRO v4 - REPORTE POA",
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.grey700)),
                pw.Text("Fecha: $fechaActual",
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              ],
            ),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 10),
          ],
        ),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text("Resumen Ejecutivo de Inversion y Cumplimiento",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
          ),
          pw.SizedBox(height: 20),

          // TABLA DE DATOS
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
            cellHeight: 30,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.center,
              4: pw.Alignment.center,
            },
            headers: ['Proyecto', 'Planificado', 'Ejecutado', '% Avance', 'Estado'],
            data: data.map((p) {
              double real = (p['monto_real'] ?? 0).toDouble();
              double plan = (p['monto_plan'] ?? 1).toDouble();
              double avance = (real / plan * 100).clamp(0, 100);

              // Lógica de Estado para el reporte
              int dias = DateTime.now().difference(DateTime.parse(p['fecha_inicio'])).inDays;
              double esperado = (dias / p['plazo'] * 100).clamp(0, 100);
              String estado = avance >= esperado ? "A TIEMPO" : "RETRASO";

              return [
                p['nombre'],
                "\$${plan.toStringAsFixed(2)}",
                "\$${real.toStringAsFixed(2)}",
                "${avance.toInt()}%",
                estado,
              ];
            }).toList(),
          ),

          pw.SizedBox(height: 30),

          // RESUMEN FINAL
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("Notas de Seguimiento:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Bullet(text: "Los valores ejecutados se calculan mediante levantamiento GIS (Cantidad x Precio)."),
                pw.Bullet(text: "El cumplimiento se mide frente al plazo total de ${data.isNotEmpty ? data[0]['plazo'] : 0} dias."),
              ],
            ),
          ),
        ],
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text("Pagina ${context.pageNumber} de ${context.pagesCount}",
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
        ),
      ),
    );

    // Lanza la interfaz de impresion o compartir nativa
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Reporte_POA_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }
}
