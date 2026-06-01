import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'database_helper.dart';
import 'config_webservice.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

class ApiService {
  final String url = "${AppConfig.baseUrl}/api/sincronizarobras";

  /// Normaliza y sanea las cadenas Base64 largas provenientes de Odoo ERP
  String? normalizarBase64(dynamic valor) {
    if (valor == null) return null;
    String str = valor.toString().trim();
    if (str.isEmpty) return null;
    str = str.replaceAll('\n', '').replaceAll('\r', '').replaceAll(' ', '');
    int mod = str.length % 4;
    if (mod > 0) {
      str += '=' * (4 - mod);
    }
    return str;
  }

  /// =========================================================================
  /// SOLUCIÓN AL ERROR DE CAPTURA: MOTOR DE HOMOLOGACIÓN TERRITORIAL
  /// =========================================================================
  String _normalizarParroquiaOtavalo(dynamic valor) {
    if (valor == null || valor == false) return 'OTAVALO';

    // 1. Limpieza base de espacios y conversión rígida a letras mayúsculas
    String texto = valor.toString().trim().toUpperCase();

    // 2. Diccionario de remoción matemática de acentos/tildes para evitar descalces en SQLite
    texto = texto.replaceAll(RegExp(r'[ÁÀÄÂ]'), 'A');
    texto = texto.replaceAll(RegExp(r'[ÉÈËÊ]'), 'E');
    texto = texto.replaceAll(RegExp(r'[ÍÌÏÎ]'), 'I');
    texto = texto.replaceAll(RegExp(r'[ÓÒÖÔ]'), 'O');
    texto = texto.replaceAll(RegExp(r'[ÚÙÜÛ]'), 'U');
    texto = texto.replaceAll('Ñ', 'N');

    // 3. Mapeo de contingencia para las nomenclaturas institucionales del GADMO
    if (texto.contains('QUICHINCHE') || texto.contains('SAN JOSE DE QUICHINCHE')) return 'SAN JOSE DE QUICHINCHE';
    if (texto.contains('SELVA ALEGRE')) return 'SELVA ALEGRE';
    if (texto.contains('PATAQUI')) return 'PATAQUI';
    if (texto.contains('SAN PABLO')) return 'SAN PABLO';
    if (texto.contains('GONZALEZ SUAREZ')) return 'GONZALEZ SUAREZ';
    if (texto.contains('SAN RAFAEL')) return 'SAN RAFAEL';
    if (texto.contains('ILUMAN') || texto.contains('SAN JUAN DE ILUMAN')) return 'SAN JUAN DE ILUMAN';
    if (texto.contains('MIGUEL EGAS') || texto.contains('PEGUCHE') || texto.contains('DOCTOR MIGUEL EGAS')) return 'DOCTOR MIGUEL EGAS CABEZAS';
    if (texto.contains('EUGENIO ESPEJO')) return 'EUGENIO ESPEJO';

    // Segmentación Urbana/Rural del Jordán y San Luis
    if (texto == 'EL JORDAN' || texto.contains('JORDAN URBANO')) return 'EL JORDAN URBANO';
    if (texto.contains('JORDAN RURAL')) return 'EL JORDAN RURAL';
    if (texto == 'SAN LUIS' || texto.contains('SAN LUIS URBANO')) return 'SAN LUIS URBANO';
    if (texto.contains('SAN LUIS RURAL')) return 'SAN LUIS RURAL';

    // Listado estricto validado por la restricción CHECK de tu base de datos
    const List<String> parroquiasValidas = [
      'SELVA ALEGRE', 'PATAQUI', 'SAN JOSE DE QUICHINCHE', 'SAN PABLO',
      'GONZALEZ SUAREZ', 'SAN RAFAEL', 'SAN JUAN DE ILUMAN',
      'DOCTOR MIGUEL EGAS CABEZAS', 'EUGENIO ESPEJO', 'EL JORDAN URBANO',
      'EL JORDAN RURAL', 'SAN LUIS URBANO', 'SAN LUIS RURAL', 'OTAVALO'
    ];

    if (parroquiasValidas.contains(texto)) {
      return texto;
    }

    return 'OTAVALO'; // Respaldo preventivo institucional por defecto si no hay coincidencia
  }
  Future<Map<String, dynamic>> sincronizarBidireccional() async {
    try {
      HttpOverrides.global = MyHttpOverrides();
      final dbHelper = DatabaseHelper.instance;

      // 1. Obtener datos locales para SUBIR a Odoo
      final proyectosLocales = await dbHelper.obtenerProyectos();
      final database = await dbHelper.database;

      List<Map<String, dynamic>> payload = [];
      for (var p in proyectosLocales) {
        final grupos = await database.query('hitos_grupos', where: 'proyecto_id = ?', whereArgs: [p['id']]);
        List<Map<String, dynamic>> gruposJSON = [];

        for (var g in grupos) {
          final hitos = await database.query('hitos', where: 'grupo_id = ?', whereArgs: [g['id']]);
          List<Map<String, dynamic>> hitosJSON = [];

          for (var h in hitos) {
            final geos = await database.query('geografias', where: 'hito_id = ?', whereArgs: [h['id']]);

            hitosJSON.add({
              'rubro': h['rubro'],
              'descripcion': h['descripcion'],
              'cantidad': h['cantidad'],
              'precio_unitario': h['precio_unitario'],
              'fecha_inicio': h['fecha_inicio'],
              'estado': h['estado'] ?? 'Inicio',
              'fotografia': h['fotografia'],
              'cumplido': h['cumplido'] ?? 0,
              'geografias': geos.map((geo) {
                String coords = geo['coordenadas']?.toString() ?? '{}';
                if (coords.trim().isEmpty) coords = '{}';

                String? foto = geo['fotografia']?.toString();
                if (foto != null && foto.trim().isEmpty) foto = null;

                return {
                  'tipo_geo': geo['tipo_geo'] ?? 'Point',
                  'descripcion': geo['descripcion'] ?? '',
                  'coordenadas': coords,
                  'fotografia': foto,
                };
              }).toList()
            });
          }

          gruposJSON.add({
            'nombre': g['nombre'],
            'hitos': hitosJSON
          });
        }

        payload.add({
          'id': p['id'],
          'nombre': p['nombre'],
          'contratista': p['contratista'],
          'monto_total': p['monto_total'],
          'presupuesto_devengado': p['presupuesto_devengado'] ?? 0.0,
          'fecha_inicio': p['fecha_inicio'],
          'plazo': p['plazo'],
          'fecha_final': p['fecha_final'],
          'canton': p['canton'],
          'parroquia': p['parroquia'], // Sube el campo local limpio
          'barrio': p['barrio'],
          'coordenadas_maestras': p['coordenadas_maestras'],
          'administrador_contrato': p['administrador_contrato'],
          'contacto_comunidad': p['contacto_comunidad'],
          'observacion': p['observacion'],
          'grupos': gruposJSON
        });
      }

      // 2. Enviar a Odoo ERP mediante JSON-RPC
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "jsonrpc": "2.0",
          "method": "call",
          "params": {"data": payload}
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final jsonRes = jsonDecode(response.body);

        if (jsonRes['result'] != null && jsonRes['result']['status'] == 'success') {
          List<dynamic> dataOdoo = jsonRes['result']['data'];

          // 3. PROCESAMIENTO Y SANEAMIENTO DE FILTRADO DE ENTRADA
          for (var item in dataOdoo) {
            if (item['grupos'] != null) {
              for (var g in item['grupos']) {
                if (g['hitos'] != null) {
                  for (var h in g['hitos']) {
                    h['fotografia'] = normalizarBase64(h['fotografia']);
                    if (h['geografias'] != null) {
                      for (var geo in h['geografias']) {
                        geo['fotografia'] = normalizarBase64(geo['fotografia']);
                      }
                    }
                  }
                }
              }
            }

            // =================================================================
            // DETECCIÓN Y REPARACIÓN DEL ERROR EN CALIENTE
            // =================================================================
            // Obligamos al valor de Odoo a pasar por el limpiador territorial
            // antes de tocar el dbHelper.
            item['parroquia'] = _normalizarParroquiaOtavalo(item['parroquia']);
            // =================================================================

            // Inserción física blindada en SQLite
            await dbHelper.insertarOActualizarDesdeOdoo(item);

            // Recalcular montos contractuales reales y semáforos de atraso localmente
            if (item['id'] != null) {
              await dbHelper.auditarProyecto(item['id']);
            }
          }
          return {"success": true, "message": "Sincronización Exitosa"};
        } else {
          return {"success": false, "message": jsonRes['result']?['message'] ?? "Error desconocido"};
        }
      }
      return {"success": false, "message": "Error de conexión: ${response.statusCode}"};
    } catch (e) {
      return {"success": false, "message": "Error crítico: $e"};
    }
  }
}
