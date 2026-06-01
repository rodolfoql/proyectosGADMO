import 'dart:io';
import 'package:excel/excel.dart'; // Requiere 'excel' en pubspec.yaml
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'database_helper.dart';

class ExcelExportServiceAlternativo {

  /// Genera un reporte Excel completo de un proyecto, incluyendo subproyectos, suspensiones, ampliaciones y multas
  static Future<void> exportarTodoElPortafolio(int proyectoPrincipalId) async {
    final dbHelper = DatabaseHelper.instance;
    final db = await dbHelper.database;

    // 1. Recuperar los datos de la Obra Matriz / Principal desde SQLite
    final List<Map<String, dynamic>> resPadre = await db.query(
      'proyectos',
      where: 'id = ?',
      whereArgs: [proyectoPrincipalId],
    );

    if (resPadre.isEmpty) {
      throw Exception("El proyecto con ID $proyectoPrincipalId no existe.");
    }

    final Map<String, dynamic> proyectoPadre = resPadre.first;

    // 2. Recuperar TODOS los subproyectos (hijos) asociados a este padre
    final List<Map<String, dynamic>> subproyectos = await db.query(
      'proyectos',
      where: 'proyecto_padre_id = ?',
      whereArgs: [proyectoPrincipalId],
      orderBy: 'nombre ASC',
    );

    List<Map<String, dynamic>> universoObras = [];
    universoObras.add({...proyectoPadre, 'tipo_jerarquia': 'PROYECTO PADRE'});
    for (var sub in subproyectos) {
      universoObras.add({...sub, 'tipo_jerarquia': 'SUBOBRA'});
    }

    List<int> todosLosIds = [proyectoPrincipalId];
    for (var sub in subproyectos) {
      todosLosIds.add(sub['id'] as int);
    }

    // 3. Inicializar el motor de libros Excel y renombrar las hojas de cálculo
    var excel = Excel.createExcel();
    excel.rename('Sheet1', 'Resumen Financiero');

    Sheet sheetFinanzas = excel['Resumen Financiero'];
    Sheet sheetSuspensiones = excel['Historial Suspensiones'];
    Sheet sheetAmpliaciones = excel['Historial Ampliaciones'];
    Sheet sheetMultas = excel['Historial Multas'];

    // =========================================================================
    // SOLUCIÓN AL ERROR 1: CORRECCIÓN DE LA PROPIEDAD HORIZONTALALIGNMENT
    // =========================================================================
    CellStyle headerStyle = CellStyle();
    headerStyle.fontColor = ExcelColor.fromHexString('#FFFFFF');       // Texto Blanco
    headerStyle.backgroundColor = ExcelColor.fromHexString('#1E293B'); // Fondo Pizarra
    headerStyle.isBold = true;
    // =========================================================================

    // =========================================================================
    // PESTAÑA 1: RESUMEN FINANCIERO Y CONTRACTUAL DE OBRAS (CORREGIDO)
    // =========================================================================
    // SOLUCIÓN AL ERROR 2: Envoltura explícita en TextCellValue para erradicar las líneas rojas
    List<CellValue> headersFinanzas = [
      TextCellValue('JERARQUÍA'),
      TextCellValue('CÓDIGO CONTRATO'),
      TextCellValue('NOMBRE DEL PROYECTO / SUBOBRA'),
      TextCellValue('FISCALIZADOR'),
      TextCellValue('CONTRATISTA'),
      TextCellValue('ESTADO'),
      TextCellValue('MONTO POA'),
      TextCellValue('DEVENGADO'),
      TextCellValue('SALDO'),
      TextCellValue('PLAZO ORIG.'),
      TextCellValue('PLAZO DINÁMICO')
    ];
    sheetFinanzas.appendRow(headersFinanzas);

    for (int i = 0; i < headersFinanzas.length; i++) {
      sheetFinanzas.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = headerStyle;
    }

    for (var obra in universoObras) {
      // Saneamiento de datos dinámicos usando los constructores nativos de la librería
      String nombreSaneado = (obra['nombre'] ?? '').toString().toUpperCase();

      sheetFinanzas.appendRow([
        TextCellValue(obra['tipo_jerarquia'] ?? ''),
        TextCellValue(obra['codigo_contrato'] ?? 'S/N'),
        TextCellValue(nombreSaneado), // <-- ERROR CORREGIDO: Ya no colapsa por tipados dinámicos
        TextCellValue(obra['fiscalizador'] ?? 'S/N'),
        TextCellValue(obra['contratista'] ?? 'S/N'),
        TextCellValue(obra['estado_proyecto'] ?? 'EN EJECUCION'),
        DoubleCellValue((obra['monto_total'] as num?)?.toDouble() ?? 0.0),
        DoubleCellValue((obra['presupuesto_devengado'] as num?)?.toDouble() ?? 0.0),
        DoubleCellValue((obra['saldo'] as num?)?.toDouble() ?? 0.0),
        IntCellValue(obra['plazo'] ?? 0),
        IntCellValue(obra['plazo_dinamico'] ?? obra['plazo'] ?? 0),
      ]);
    }
    // =========================================================================
    // PESTAÑA 2: HISTORIAL CRONOLÓGICO DE SUSPENSIONES (CORREGIDO)
    // =========================================================================
    List<CellValue> headersSuspensiones = [
      TextCellValue('CÓDIGO CONTRATO'),
      TextCellValue('OBRA / PROYECTO'),
      TextCellValue('FECHA INICIO'),
      TextCellValue('FECHA REACTIVACIÓN'),
      TextCellValue('ESTADO'),
      TextCellValue('DÍAS SUSPENDIDOS'),
      TextCellValue('MOTIVO / JUSTIFICACIÓN')
    ];
    sheetSuspensiones.appendRow(headersSuspensiones);
    for (int i = 0; i < headersSuspensiones.length; i++) {
      sheetSuspensiones.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = headerStyle;
    }

    String placeHolders = todosLosIds.map((_) => '?').join(', ');
    final List<Map<String, dynamic>> suspensionesRaw = await db.rawQuery('''
      SELECT s.*, p.nombre as proy_nombre, p.codigo_contrato 
      FROM suspensiones s
      JOIN proyectos p ON s.proyecto_id = p.id
      WHERE s.proyecto_id IN ($placeHolders)
      ORDER BY s.fecha_suspension DESC
    ''', todosLosIds);

    for (var s in suspensionesRaw) {
      sheetSuspensiones.appendRow([
        TextCellValue(s['codigo_contrato'] ?? 'S/N'),
        TextCellValue((s['proy_nombre'] ?? '').toString().toUpperCase()),
        TextCellValue(s['fecha_suspension'] ?? 'S/F'),
        TextCellValue(s['fecha_reactivacion'] ?? 'ACTIVA (Sin alzar)'),
        TextCellValue(s['estado'] ?? 'SUSPENDIDO'),
        IntCellValue(s['total_dias_suspendido'] ?? 0),
        TextCellValue(s['motivo_suspension'] ?? ''),
      ]);
    }
    // =========================================================================
    // PESTAÑA 3: HISTORIAL DE AMPLIACIONES DE PLAZO CONTRACTUAL (CORREGIDO)
    // =========================================================================
    List<CellValue> headersAmpliaciones = [
      TextCellValue('CÓDIGO CONTRATO'),
      TextCellValue('OBRA / PROYECTO'),
      TextCellValue('FECHA APROBACIÓN'),
      TextCellValue('DÍAS OTORGADOS'),
      TextCellValue('JUSTIFICACIÓN / ADENDUM')
    ];
    sheetAmpliaciones.appendRow(headersAmpliaciones);
    for (int i = 0; i < headersAmpliaciones.length; i++) {
      sheetAmpliaciones.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = headerStyle;
    }

    final List<Map<String, dynamic>> ampliacionesRaw = await db.rawQuery('''
      SELECT a.*, p.nombre as proy_nombre, p.codigo_contrato 
      FROM ampliaciones a
      JOIN proyectos p ON a.proyecto_id = p.id
      WHERE a.proyecto_id IN ($placeHolders)
      ORDER BY a.fecha_ampliacion DESC
    ''', todosLosIds);

    for (var a in ampliacionesRaw) {
      sheetAmpliaciones.appendRow([
        TextCellValue(a['codigo_contrato'] ?? 'S/N'),
        TextCellValue((a['proy_nombre'] ?? '').toString().toUpperCase()),
        TextCellValue(a['fecha_ampliacion'] ?? 'S/F'),
        IntCellValue(a['nro_dias_ampliacion'] ?? 0),
        TextCellValue(a['motivo_ampliacion'] ?? ''),
      ]);
    }

    // =========================================================================
    // PESTAÑA 4: HISTORIAL DE MULTAS Y PENALIZACIONES ECONÓMICAS (CORREGIDO)
    // =========================================================================
    List<CellValue> headersMultas = [
      TextCellValue('CÓDIGO CONTRATO'),
      TextCellValue('OBRA / PROYECTO'),
      TextCellValue('VALOR ECONÓMICO (\$)'),
      TextCellValue('ESTADO'),
      TextCellValue('CONCEPTO SANCIÓN')
    ];
    sheetMultas.appendRow(headersMultas);
    for (int i = 0; i < headersMultas.length; i++) {
      sheetMultas.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = headerStyle;
    }

    final List<Map<String, dynamic>> multasRaw = await db.rawQuery('''
      SELECT m.*, p.nombre as proy_nombre, p.codigo_contrato 
      FROM multas m
      JOIN proyectos p ON m.proyecto_id = p.id
      WHERE m.proyecto_id IN ($placeHolders)
      ORDER BY m.id DESC
    ''', todosLosIds);

    for (var m in multasRaw) {
      sheetMultas.appendRow([
        TextCellValue(m['codigo_contrato'] ?? 'S/N'),
        TextCellValue((m['proy_nombre'] ?? '').toString().toUpperCase()),
        DoubleCellValue((m['valor'] as num?)?.toDouble() ?? 0.0),
        TextCellValue(m['estado'] ?? 'APLICADA'),
        TextCellValue(m['motivo_multa'] ?? ''),
      ]);
    }

    // =========================================================================
    // BLOQUE DE CIERRE, PERSISTENCIA EN DISCO Y COMPARTICIÓN MULTIMEDIA
    // =========================================================================
    List<int>? fileBytes = excel.save();
    if (fileBytes == null) return;

    final String nombreLimpio = proyectoPadre['nombre'].toString().replaceAll(RegExp(r'[^\w\s]+'), '_');
    final directory = await getTemporaryDirectory();
    final String pathFinal = "${directory.path}/REPORTE_CONSOLIDADO_$nombreLimpio.xlsx";

    final File file = File(pathFinal);
    await file.writeAsBytes(fileBytes, flush: true);

    // Despacha de forma nativa la hoja de cálculo por WhatsApp, Correo o Bluetooth
    await Share.shareXFiles(
        [XFile(pathFinal)],
        text: "Reporte Fiscal y Legal de la Obra: ${proyectoPadre['nombre'].toString().toUpperCase()}"
    );
  }
}
