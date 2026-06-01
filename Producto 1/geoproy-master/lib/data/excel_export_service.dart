import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart'; // Módulo de compartición nativa
import 'database_helper.dart';

class ExcelExportService {

  /// Función maestra que genera el reporte en Excel y abre la ventana para compartir por WhatsApp o Correo
  static Future<bool> exportarTodoElPortafolio(int proyectoId) async {
    try {
      final db = DatabaseHelper.instance;

      // 1. OBTENER INFORMACIÓN DE TODAS LAS SUBTABLAS ASOCIADAS
      final List<Map<String, dynamic>> resProy = await (await db.database).query('proyectos', where: 'id = ?', whereArgs: [proyectoId]);
      if (resProy.isEmpty) return false;
      final proy = resProy.first;

      final List<Map<String, dynamic>> suspensiones = await db.obtenerSuspensionesProyecto(proyectoId);
      final List<Map<String, dynamic>> ampliaciones = await db.obtenerAmpliacionesProyecto(proyectoId);
      final List<Map<String, dynamic>> grupos = await db.obtenerGruposPorProyecto(proyectoId);

      // 2. INICIALIZAR EL LIBRO BINARIO DE EXCEL
      var excel = Excel.createExcel();
      String sheetName = "Fiscalización Obras";
      excel.rename(excel.getDefaultSheet()!, sheetName);
      Sheet sheet = excel[sheetName];

      // SOLUCIÓN DEFINITIVA: Estilos basados puramente en fuentes universales estables (Sin inyección de cellColor)
      CellStyle headerStyle = CellStyle(
        bold: true,
        fontFamily: getFontFamily(FontFamily.Arial),
      );

      CellStyle subHeaderStyle = CellStyle(
        bold: true,
        fontFamily: getFontFamily(FontFamily.Arial),
      );

      // 3. AGREGAR CABECERA PRINCIPAL DEL PROYECTO
      sheet.appendRow([TextCellValue("REPORTE CONSOLIDADO DE FISCALIZACIÓN MUNICIPAL - GAD OTAVALO")]);
      sheet.appendRow([]);

      sheet.appendRow([TextCellValue("INFORMACIÓN GENERAL GENERAL")]);
      sheet.appendRow([TextCellValue("Código Contrato:"), TextCellValue("${proy['codigo_contrato'] ?? 'S/N'}")]);
      sheet.appendRow([TextCellValue("Proyecto / Obra:"), TextCellValue("${proy['nombre'].toString().toUpperCase()}")]);
      sheet.appendRow([TextCellValue("Contratista:"), TextCellValue("${proy['contratista'] ?? 'S/N'}")]);
      sheet.appendRow([TextCellValue("Fiscalizador:"), TextCellValue("${proy['fiscalizador'] ?? 'S/N'}")]);
      sheet.appendRow([TextCellValue("Parroquia / Barrio:"), TextCellValue("${proy['parroquia']} - ${proy['barrio'] ?? ''}")]);
      sheet.appendRow([TextCellValue("Monto Contractual Total:"), DoubleCellValue((proy['monto_total'] as num).toDouble())]);
      sheet.appendRow([TextCellValue("Presupuesto Devengado:"), DoubleCellValue((proy['presupuesto_devengado'] as num).toDouble())]);
      sheet.appendRow([TextCellValue("Saldo por Ejecutar:"), DoubleCellValue((proy['saldo'] as num).toDouble())]);
      sheet.appendRow([TextCellValue("Porcentaje Avance Real:"), TextCellValue("${proy['porcentaje_avance']}%")]);

      // Control Cronológico Dinámico (Puntos 5 y 6)
      sheet.appendRow([TextCellValue("Fecha de Inicio:"), TextCellValue("${proy['fecha_inicio'] ?? ''}")]);
      sheet.appendRow([TextCellValue("Plazo Original (Días):"), IntCellValue(proy['plazo'] as int)]);
      sheet.appendRow([TextCellValue("Plazo Dinámico Actualizado:"), IntCellValue(proy['plazo_dinamico'] ?? proy['plazo'] as int)]);
      sheet.appendRow([TextCellValue("Fecha Estimada Culminación:"), TextCellValue("${proy['fecha_culminacion'] ?? ''}")]);
      sheet.appendRow([TextCellValue("Enlace Web SERCOP:"), TextCellValue("${proy['url_sercop'] ?? 'S/N'}")]);
      sheet.appendRow([]);
      // 4. AGREGAR REGISTROS DE SUSPENSIONES (Punto 7)
      sheet.appendRow([TextCellValue("HISTORIAL DE SUSPENSIONES DE OBRA")]);
      sheet.appendRow([
        TextCellValue("Motivo"),
        TextCellValue("Fecha Suspensión"),
        TextCellValue("Fecha Reactivación"),
        TextCellValue("Días Totales"),
        TextCellValue("Estado Actual")
      ]);
      sheet.row(sheet.maxRows - 1).forEach((cell) => cell?.cellStyle = subHeaderStyle);

      if (suspensiones.isEmpty) {
        sheet.appendRow([TextCellValue("No se registran suspensiones en esta obra.")]);
      } else {
        for (var s in suspensiones) {
          sheet.appendRow([
            TextCellValue(s['motivo_suspension']),
            TextCellValue(s['fecha_suspension']),
            TextCellValue(s['fecha_reactivacion'] ?? 'ACTIVA'),
            IntCellValue(s['total_dias_suspendido'] as int),
            TextCellValue(s['estado'])
          ]);
        }
      }
      sheet.appendRow([]);

      // 5. AGREGAR REGISTROS DE AMPLIACIONES DE PLAZO (Punto 8)
      sheet.appendRow([TextCellValue("HISTORIAL DE AMPLIACIONES DE PLAZO CONTRATUAL")]);
      sheet.appendRow([
        TextCellValue("Motivo Ampliación"),
        TextCellValue("Fecha Aprobación"),
        TextCellValue("Días Otorgados"),
        TextCellValue("Nueva Fecha Límite")
      ]);
      sheet.row(sheet.maxRows - 1).forEach((cell) => cell?.cellStyle = subHeaderStyle);

      if (ampliaciones.isEmpty) {
        sheet.appendRow([TextCellValue("No se registran ampliaciones de tiempo en esta obra.")]);
      } else {
        for (var a in ampliaciones) {
          sheet.appendRow([
            TextCellValue(a['motivo_ampliacion']),
            TextCellValue(a['fecha_ampliacion']),
            IntCellValue(a['nro_dias_ampliacion'] as int),
            TextCellValue(a['fecha_final'] ?? '')
          ]);
        }
      }
      sheet.appendRow([]);

      // 6. CRONOGRAMA DESGLOSADO DE RUBROS POR CAPÍTULO
      sheet.appendRow([TextCellValue("DETALLE CRONOLÓGICO FINANCIERO DE RUBROS TÉCNICOS")]);

      for (var g in grupos) {
        sheet.appendRow([TextCellValue("CAPÍTULO: ${g['nombre'].toString().toUpperCase()}")]);
        sheet.row(sheet.maxRows - 1).forEach((cell) => cell?.cellStyle = headerStyle);

        sheet.appendRow([
          TextCellValue("Código Rubro"),
          TextCellValue("Descripción Actividad"),
          TextCellValue("Unidad"),
          TextCellValue("Cantidad Planificada"),
          TextCellValue("Precio Unitario"),
          TextCellValue("Monto Total \$"),
          TextCellValue("Estado Fiscal")
        ]);
        sheet.row(sheet.maxRows - 1).forEach((cell) => cell?.cellStyle = subHeaderStyle);

        final List<Map<String, dynamic>> hitos = await db.obtenerHitosPorGrupo(g['id']);

        if (hitos.isEmpty) {
          sheet.appendRow([TextCellValue("Sin rubros asignados a este capítulo.")]);
        } else {
          for (var h in hitos) {
            sheet.appendRow([
              TextCellValue(h['rubro'] ?? ''),
              TextCellValue(h['descripcion'] ?? ''),
              TextCellValue(h['unidad'] ?? ''),
              DoubleCellValue((h['cantidad'] as num).toDouble()),
              DoubleCellValue((h['precio_unitario'] as num).toDouble()),
              DoubleCellValue((h['total'] as num).toDouble()),
              TextCellValue(h['cumplido'] == 1 ? 'EJECUTADO' : 'PENDIENTE')
            ]);
          }
        }
        sheet.appendRow([]);
      }

      // 7. GUARDAR TEMPORALMENTE Y ACTIVAR COMPARTICIÓN REQUERIDA
      final Directory directorioTemporal = await getTemporaryDirectory();
      final String nombreLimpio = proy['nombre'].toString().replaceAll(RegExp(r'[^\w\s]+'), '_').replaceAll(' ', '_');
      final String nombreArchivo = "Reporte_Fiscalizacion_$nombreLimpio.xlsx";
      final String rutaCompleta = "${directorioTemporal.path}/$nombreArchivo";

      final List<int>? bytesExcel = excel.encode();
      if (bytesExcel != null) {
        final File archivoFisico = File(rutaCompleta);
        await archivoFisico.writeAsBytes(bytesExcel, flush: true);

        // DISPARADOR NATIVO SHARE: Abre WhatsApp, Correo, Telegram, etc.
        await Share.shareXFiles(
          [XFile(rutaCompleta)],
          text: "Adjunto el Reporte de Fiscalización de la obra: ${proy['nombre'].toString().toUpperCase()}.\nCódigo de Contrato: ${proy['codigo_contrato'] ?? 'S/N'}.",
          subject: "Reporte de Fiscalización - GAD Otavalo",
        );
        return true;
      }

      return false;
    } catch (e) {
      print("❌ Fallo crítico en el motor de exportación/compartición Excel: $e");
      return false;
    }
  }
}
