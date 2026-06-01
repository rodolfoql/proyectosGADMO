import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'database_helper.dart';

// Permite conexiones a servidores con certificados autofirmados o problemas de cadena SSL
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

class ApiService {
  final String url = "https://geoportal.otavalo.gob.ec/api/sincronizarobras";

  // Convierte archivos locales a Base64 para campos Binary de Odoo
  Future<String?> _fileToBase64(dynamic path) async {
    if (path == null || path.toString().isEmpty) return null;
    try {
      final file = File(path.toString());
      if (await file.exists()) {
        List<int> bytes = await file.readAsBytes();
        return base64Encode(bytes);
      }
    } catch (e) {
      print("Error en conversión multimedia: $e");
    }
    return null;
  }

  Future<bool> sincronizarTodo() async {
    try {
      final db = DatabaseHelper.instance;

      // 1. Carga de datos locales
      final proyectosRaw = await db.obtenerProyectos();
      final database = await db.database; // Obtenemos la instancia una sola vez

      final gruposRaw = await database.query('hitos_grupos');
      final hitosRaw = await database.query('hitos');
      final geosRaw = await database.query('geografias');

      List<Map<String, dynamic>> payload = [];

      for (var p in proyectosRaw) {
        // NIVEL 1: PROYECTO
        Map<String, dynamic> proyMap = {
          'nombre': p['nombre'] ?? 'Sin Nombre',
          'contratista': p['contratista'] ?? '',
          'administrador_contrato': p['administrador_contrato'] ?? '',
          'monto_total': p['monto_total'] ?? 0.0,
          'plazo': p['plazo'] ?? 0,
          'fecha_inicio': p['fecha_inicio'],
          'canton': p['canton'] ?? '',
          'parroquia': p['parroquia'] ?? '',
          'barrio': p['barrio'] ?? '',
          'prioridad': (p['prioridad'] ?? 'MEDIA').toString().toUpperCase(),
          // CORRECCIÓN: El campo en Odoo se llama 'estado'
          //'estado': p['estado_sistema'] ?? 'BORRADOR',
          //'alerta_atraso': p['alerta_atraso'] == 1,
        };

        // NIVEL 2: GRUPOS
        List<Map<String, dynamic>> gruposLista = [];
        final gruposRel = gruposRaw.where((g) => g['proyecto_id'] == p['id']).toList();

        for (var g in gruposRel) {
          // NIVEL 3: HITOS
          List<Map<String, dynamic>> hitosLista = [];
          final hitosRel = hitosRaw.where((h) => h['grupo_id'] == g['id']).toList();

          for (var h in hitosRel) {
            // NIVEL 4: GEOMETRÍAS
            final geosRel = geosRaw.where((geo) => geo['hito_id'] == h['id']).toList();
            List<Map<String, dynamic>> geoLista = [];

            for (var geo in geosRel) {
              geoLista.add({
                'tipo_geo': geo['tipo_geo'] ?? 'PUNTO',
                'descripcion': geo['descripcion'] ?? '',
                'coordenadas': geo['coordenadas'] ?? '',
                //'fotografia': await _fileToBase64(geo['fotografia']),
                //'audio': await _fileToBase64(geo['audio']),
              });
            }

            hitosLista.add({
              'rubro': h['rubro'] ?? '',
              'descripcion': h['descripcion'] ?? '',
              'unidad': h['unidad'] ?? '',
              'cantidad': h['cantidad'] ?? 0.0,
              'precio_unitario': h['precio_unitario'] ?? 0.0,
              'total': h['total'] ?? 0.0,
              'fecha_inicio': h['fecha_inicio'],
              'fecha_fin': h['fecha_fin'],
              //'estado': h['estado'] ?? '',
              //'geometrias': geoLista,
            });
          }

          gruposLista.add({
            'nombre': g['nombre'] ?? 'Sin Capítulo',
            'hitos': hitosLista,
          });
        }

        proyMap['grupos'] = gruposLista;
        payload.add(proyMap);
      }

      // 3. Envío mediante JSON-RPC
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "jsonrpc": "2.0",
          "params": {"data": payload}
        }),
      ).timeout(const Duration(seconds: 180));

      if (response.statusCode == 200) {
        final Map<String, dynamic> resBody = jsonDecode(response.body);
        if (resBody.containsKey('error')) {
          print("Error Odoo (Validación): ${resBody['error']}");
          return false;
        }
        return true;
      }
      print("Error de servidor: ${response.statusCode}");
      return false;
    } catch (e) {
      print("Fallo de conexión crítico: $e");
      return false;
    }
  }
}
