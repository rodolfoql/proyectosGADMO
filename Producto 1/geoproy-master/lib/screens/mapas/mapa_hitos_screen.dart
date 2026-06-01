import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/database_helper.dart';

class MapaFiscalizacionScreen extends StatefulWidget {
  const MapaFiscalizacionScreen({super.key});

  @override
  State<MapaFiscalizacionScreen> createState() => _MapaFiscalizacionScreenState();
}

class _MapaFiscalizacionScreenState extends State<MapaFiscalizacionScreen> {
  GoogleMapController? _mapController;
  List<Map<String, dynamic>> _proyectos = [];
  int? _proyectoSeleccionadoId;
  String _nombreProyectoActivo = "Reporte";

  // Capas de Google Maps
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  Set<Polygon> _polygons = {};
  MapType _currentMapType = MapType.hybrid;

  // Datos para exportación JSON
  List<Map<String, dynamic>> _dataGisActual = [];

  @override
  void initState() {
    super.initState();
    _cargarProyectos();
  }

  void _cargarProyectos() async {
    final data = await DatabaseHelper.instance.obtenerProyectos();
    setState(() => _proyectos = data);
  }

  /// Recorre la jerarquía Proyecto > Grupo > Hito > GIS para dibujar en el mapa
  Future<void> _cargarCapaGeografica(int proyectoId) async {
    final db = DatabaseHelper.instance;
    final grupos = await db.obtenerGruposPorProyecto(proyectoId);

    Set<Marker> tempMarkers = {};
    Set<Polyline> tempPolylines = {};
    Set<Polygon> tempPolygons = {};
    List<Map<String, dynamic>> tempDataGis = [];

    for (var g in grupos) {
      final hitos = await db.obtenerHitosPorGrupo(g['id']);
      for (var h in hitos) {
        final geografias = await db.obtenerGISPorHito(h['id']);
        for (var geo in geografias) {
          // Preparar data para JSON
          tempDataGis.add({
            "rubro_num": h['rubro'],
            "hito": h['descripcion'],
            "observacion_gis": geo['descripcion'],
            "tipo": geo['tipo_geo'],
            "coordenadas": jsonDecode(geo['coordenadas']),
            "fecha": h['fecha_inicio']
          });

          List<LatLng> coords = (jsonDecode(geo['coordenadas']) as List)
              .map((e) => LatLng(e['lat'], e['lng'])).toList();

          String idStr = geo['id'].toString();

          if (geo['tipo_geo'] == 'punto') {
            tempMarkers.add(Marker(
              markerId: MarkerId(idStr),
              position: coords.first,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
              onTap: () => _mostrarDetalleEvidencia(geo, h['descripcion']),
            ));
          } else if (geo['tipo_geo'] == 'linea') {
            tempPolylines.add(Polyline(
              polylineId: PolylineId(idStr),
              points: coords,
              color: Colors.orange,
              width: 5,
              consumeTapEvents: true,
              onTap: () => _mostrarDetalleEvidencia(geo, h['descripcion']),
            ));
          } else if (geo['tipo_geo'] == 'poligono') {
            tempPolygons.add(Polygon(
              polygonId: PolygonId(idStr),
              points: coords,
              fillColor: Colors.orange.withOpacity(0.3),
              strokeColor: Colors.orange,
              strokeWidth: 2,
              consumeTapEvents: true,
              onTap: () => _mostrarDetalleEvidencia(geo, h['descripcion']),
            ));
          }
        }
      }
    }

    setState(() {
      _markers = tempMarkers;
      _polylines = tempPolylines;
      _polygons = tempPolygons;
      _dataGisActual = tempDataGis;
    });

    if (coordsListNotEmpty(tempMarkers, tempPolylines)) {
      LatLng focus = tempMarkers.isNotEmpty
          ? tempMarkers.first.position
          : tempPolylines.first.points.first;
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(focus, 16));
    }
  }

  bool coordsListNotEmpty(Set m, Set p) => m.isNotEmpty || p.isNotEmpty;

  // --- LÓGICA DE COMPARTIR (JSON + PNG) ---
  Future<void> _compartirPorWhatsapp() async {
    if (_proyectoSeleccionadoId == null || _dataGisActual.isEmpty) {
      _msg("Seleccione un proyecto con datos dibujados");
      return;
    }

    _msg("📸 Procesando captura y datos...");

    try {
      // Usar el directorio temporal es mejor para archivos que solo se van a compartir
      final directory = await getTemporaryDirectory();
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      List<XFile> filesToShare = [];

      // 1. Crear y escribir archivo JSON
      final String jsonStr = jsonEncode({
        "proyecto": _nombreProyectoActivo,
        "fecha_exportacion": DateTime.now().toIso8601String(),
        "elementos": _dataGisActual
      });

      final File jsonFile = File('${directory.path}/GIS_$timestamp.json');
      await jsonFile.writeAsString(jsonStr);
      filesToShare.add(XFile(jsonFile.path, mimeType: 'application/json'));

      // 2. Captura de pantalla del mapa
      // Asegúrate de que el controlador no sea nulo y la captura sea exitosa
      if (_mapController != null) {
        final Uint8List? imageBytes = await _mapController?.takeSnapshot();
        if (imageBytes != null && imageBytes.isNotEmpty) {
          final File imgFile = File('${directory.path}/Captura_$timestamp.png');
          await imgFile.writeAsBytes(imageBytes);
          filesToShare.add(XFile(imgFile.path, mimeType: 'image/png'));
        }
      }

      // 3. Lanzar menú de compartir si hay archivos
      if (filesToShare.isNotEmpty) {
        await Share.shareXFiles(
          filesToShare,
          text: '📌 Levantamiento Técnico: $_nombreProyectoActivo\nSistema Geoproy v1',
        );
      } else {
        _msg("Error: No se generaron archivos para compartir");
      }

    } catch (e) {
      debugPrint("Error en _compartirPorWhatsapp: $e");
      _msg("Error: No se pudo compartir la información");
    }
  }

  void _mostrarDetalleEvidencia(Map<String, dynamic> geo, String hitoNombre) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.65,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 15),
            Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hitoNombre.toUpperCase(), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF1E293B))),
                    const SizedBox(height: 10),
                    Text(geo['descripcion'] ?? "Sin descripción técnica", style: TextStyle(color: Colors.grey[700], fontSize: 14)),
                    const Divider(height: 30),
                    if (geo['fotografia'] != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.file(File(geo['fotografia']), height: 250, width: double.infinity, fit: BoxFit.cover),
                      )
                    else
                      Container(
                        height: 150, width: double.infinity,
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(20)),
                        child: const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                      ),
                    const SizedBox(height: 20),
                    if (geo['audio'] != null)
                      ListTile(
                        tileColor: Colors.cyanAccent.withOpacity(0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        leading: const Icon(Icons.mic, color: Color(0xFF1E293B)),
                        title: const Text("Nota de Voz Técnica", style: TextStyle(fontWeight: FontWeight.bold)),
                        trailing: const Icon(Icons.play_circle_fill, size: 35),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Levantamientos Gis"),
        actions: [
          PopupMenuButton<MapType>(
            icon: const Icon(Icons.layers_outlined),
            onSelected: (t) => setState(() => _currentMapType = t),
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: MapType.normal, child: Text("Normal")),
              const PopupMenuItem(value: MapType.satellite, child: Text("Satelital")),
              const PopupMenuItem(value: MapType.hybrid, child: Text("Híbrido")),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.greenAccent),
            onPressed: _compartirPorWhatsapp,
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: DropdownButtonFormField<int>(
              isExpanded: true,
              decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                  hintText: "Seleccione Proyecto para Ubicar",
                  prefixIcon: const Icon(Icons.apartment_rounded)
              ),
              items: _proyectos.map((p) => DropdownMenuItem(
                value: p['id'] as int,
                child: Text(p['nombre'].toString().toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              )).toList(),
              onChanged: (val) {
                setState(() {
                  _proyectoSeleccionadoId = val;
                  _nombreProyectoActivo = _proyectos.firstWhere((e) => e['id'] == val)['nombre'];
                });
                if (val != null) _cargarCapaGeografica(val);
              },
            ),
          ),
        ),
      ),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(target: LatLng(0.2268, -78.2629), zoom: 12),
        mapType: _currentMapType,
        markers: _markers,
        polylines: _polylines,
        polygons: _polygons,
        onMapCreated: (c) => _mapController = c,
        myLocationEnabled: true,
        compassEnabled: true,
      ),
    );
  }

  void _msg(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t), behavior: SnackBarBehavior.floating));
}
