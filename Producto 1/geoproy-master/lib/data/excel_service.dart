import 'dart:io';
import 'package:excel/excel.dart';
import 'database_helper.dart';

class ExcelImportService {
  /// Importación avanzada de presupuestos con homologación SERCOP y prevención de duplicados
  static Future<bool> importarPresupuesto(String filePath, int proyectoId) async {
    try {
      // 1. Leer el archivo físico y decodificar bytes
      var bytes = File(filePath).readAsBytesSync();
      var excel = Excel.decodeBytes(bytes);
      final dbHelper = DatabaseHelper.instance;
      final db = await dbHelper.database;

      // Caché temporal en memoria para reutilizar IDs de capítulos y evitar duplicados en el lote
      Map<String, int> capitulosEnMemoria = {};

      // 2. Iterar por cada hoja del libro de Excel
      for (var table in excel.tables.keys) {
        int? currentGrupoId;
        var rows = excel.tables[table]!.rows;

        // Omitimos la primera fila (encabezado) de forma segura
        for (var row in rows.skip(1)) {

          // --- VALIDACIÓN: FILAS COMPLETAMENTE VACÍAS ---
          bool filaTieneDatos = row.any((cell) =>
          cell?.value != null && cell!.value.toString().trim().isNotEmpty
          );

          if (row.isEmpty || !filaTieneDatos) continue;

          // --- BLINDAJE CONTRA FILAS CORTAS (Evita Index Out of Bounds) ---
          // El presupuesto mínimo requiere 5 columnas (A hasta E, índices 0 a 4)
          if (row.length < 5) continue;

          // Mapeo defensivo de strings de celdas utilizando escapes de nulos
          var valRubro  = row[0]?.value?.toString().trim() ?? '';
          var valDesc   = row[1]?.value?.toString().trim();
          var valUnidad = row[2]?.value?.toString().trim() ?? 'u';
          var valCant   = row[3]?.value?.toString().trim();

          // Filtro secundario de seguridad para ignorar cabeceras repetidas en el cuerpo
          if (valDesc == null || valDesc.toLowerCase() == 'descripcion' || valDesc.toLowerCase() == 'detalle') continue;

          // ===================================================================
          // LÓGICA DE DETECCIÓN: CAPÍTULO (GRUPO) vs RUBRO (HITO)
          // ===================================================================

          // CASO A: Si no hay cantidad, asumimos estructuralmente que es un Capítulo
          if (valCant == null || valCant.isEmpty || valCant.toLowerCase() == 'null') {
            String nombreCapitulo = valDesc.toUpperCase();

            // Verificamos si ya procesamos este capítulo en este bucle
            if (capitulosEnMemoria.containsKey(nombreCapitulo)) {
              currentGrupoId = capitulosEnMemoria[nombreCapitulo];
            } else {
              // Verificamos si ya existe físicamente en SQLite para este proyecto
              final List<Map<String, dynamic>> grupoExistente = await db.query(
                'hitos_grupos',
                where: 'nombre = ? AND proyecto_id = ?',
                whereArgs: [nombreCapitulo, proyectoId],
              );

              if (grupoExistente.isNotEmpty) {
                currentGrupoId = grupoExistente.first['id'] as int;
              } else {
                // Inserción limpia utilizando el método de tu instancia helper
                currentGrupoId = await dbHelper.insertarGrupo({
                  'proyecto_id': proyectoId,
                  'nombre': nombreCapitulo,
                });
              }
              // Cacheamos el ID para las siguientes filas
              capitulosEnMemoria[nombreCapitulo] = currentGrupoId!;
            }
          }
          // CASO B: Si hay cantidad, procesamos como Rubro Técnico (Hito)
          else {
            double cantidad = double.tryParse(valCant.replaceAll(',', '.')) ?? 0.0;

            // Lectura segura del precio unitario en la columna E (índice 4)
            String valPUnit = row.length > 4 ? (row[4]?.value?.toString() ?? '0') : '0';
            double pUnit = double.tryParse(valPUnit.replaceAll(',', '.')) ?? 0.0;

            // Ignorar rubros basura con cantidades inexistentes o negativas
            if (cantidad <= 0 && pUnit <= 0) continue;

            // --- TRATAMIENTO DE HOMOLOGACIÓN DE UNIDADES (Evita quiebres por CHECK SQL) ---
            String unidadLimpia = valUnidad.toLowerCase().replaceAll('.', '').trim();

            if (unidadLimpia == 'und' || unidadLimpia == 'unidad' || unidadLimpia == 'unidades') unidadLimpia = 'u';
            if (unidadLimpia == 'glb' || unidadLimpia == 'global' || unidadLimpia == 'gl') unidadLimpia = 'glb';
            if (unidadLimpia == 'm' || unidadLimpia == 'metro' || unidadLimpia == 'mts' || unidadLimpia == 'ml') unidadLimpia = 'm';
            if (unidadLimpia == 'm2' || unidadLimpia == 'metro cuadrado' || unidadLimpia == 'm2') unidadLimpia = 'm2';
            if (unidadLimpia == 'm3' || unidadLimpia == 'metro cubico' || unidadLimpia == 'm3') unidadLimpia = 'm3';
            if (unidadLimpia == 'kg' || unidadLimpia == 'kilogramo' || unidadLimpia == 'kgs' || unidadLimpia == 'kilos') unidadLimpia = 'kg';
            if (unidadLimpia == 'jgo' || unidadLimpia == 'juego' || unidadLimpia == 'juegos') unidadLimpia = 'jgo';
            if (unidadLimpia == 'km' || unidadLimpia == 'kilometro' || unidadLimpia == 'kms') unidadLimpia = 'km';
            if (unidadLimpia == 'pto' || unidadLimpia == 'punto' || unidadLimpia == 'puntos') unidadLimpia = 'pto';
            if (unidadLimpia == 'ha' || unidadLimpia == 'hectarea' || unidadLimpia == 'hectareas') unidadLimpia = 'Ha';

            // Listado estricto definido en tu restricción CHECK de base de datos
            const List<String> catalogoValido = ['u','kg','m','m2','m3','ml','jgo','glb','km','pto','Ha'];
            if (!catalogoValido.contains(unidadLimpia)) {
              unidadLimpia = 'u'; // Respaldo preventivo institucional para no romper la transacción
            }

            // Validar si el rubro ya existe en este capítulo específico para actualizar en vez de duplicar
            int grupoIdDestino = currentGrupoId ?? 1;
            final List<Map<String, dynamic>> hitoExistente = await db.query(
              'hitos',
              where: 'rubro = ? AND grupo_id = ?',
              whereArgs: [valRubro, grupoIdDestino],
            );

            Map<String, dynamic> hitoData = {
              'grupo_id': grupoIdDestino,
              'rubro': valRubro,
              'descripcion': valDesc,
              'unidad': unidadLimpia, // Inyección de la unidad 100% homologada
              'cantidad': cantidad,
              'precio_unitario': pUnit,
              'total': cantidad * pUnit,
              'fecha_inicio': DateTime.now().toIso8601String().split('T')[0],
              'plazo': 1, // Inicializador base para el cálculo de cronogramas
              'estado': 'Inicio',
              'cumplido': 0
            };

            if (hitoExistente.isNotEmpty) {
              await db.update('hitos', hitoData, where: 'id = ?', whereArgs: [hitoExistente.first['id']]);
            } else {
              // Usamos tu método original que además invoca internamente la auditoría del proyecto
              await dbHelper.insertarHito(hitoData, proyectoId);
            }
          }
        }
      }

      // 3. DISPARADOR DE CONSOLIDACIÓN TÉCNICA
      // Obligamos a la base de datos local a recalcular de forma masiva los devengados,
      // saldos y semáforos de avance reflejando inmediatamente la carga del Excel en el Dashboard.
      await dbHelper.auditarProyecto(proyectoId);
      return true;

    } catch (e) {
      print("❌ Error crítico en el motor de importación ExcelImportService: $e");
      return false;
    }
  }
}
