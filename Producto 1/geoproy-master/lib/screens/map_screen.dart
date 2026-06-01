import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:record/record.dart';
import 'dart:convert';
import 'dart:io';
import '../data/database_helper.dart';
import 'package:utm/utm.dart';

class MapHitoScreen extends StatefulWidget {
  final int hitoId;
  const MapHitoScreen({super.key, required this.hitoId});

  @override
  State<MapHitoScreen> createState() => _MapHitoScreenState();
}

class _MapHitoScreenState extends State<MapHitoScreen> {
  GoogleMapController? _mapController;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final TextEditingController _descController = TextEditingController();

  MapType _currentMapType = MapType.normal;
  LatLng _mapCenter = const LatLng(0.2268, -78.2629);

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  Set<Polygon> _polygons = {};
  List<LatLng> _puntosActuales = [];

  String _modoGeo = 'linea';
  String? _pathFoto;
  String? _pathAudio;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
    _determinarPosicionInicial();
  }

  @override
  void dispose() {
    _descController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  // --- LÓGICA DE DIBUJO TIPO QFIELD ---

  void _onCameraMove(CameraPosition position) {
    setState(() {
      _mapCenter = position.target;
    });
  }

  void _agregarPuntoDePrecision() {
    setState(() {
      if (_modoGeo == 'punto') {
        _puntosActuales = [_mapCenter];
      } else {
        _puntosActuales.add(_mapCenter);
      }
      _actualizarCapasVisuales();
    });
  }

  void _actualizarCapasVisuales() {
    _markers.removeWhere((m) => m.markerId.value == "preview");
    _polylines.removeWhere((p) => p.polylineId.value == "preview");
    _polygons.removeWhere((pg) => pg.polygonId.value == "preview");

    if (_puntosActuales.isEmpty) return;

    if (_modoGeo == 'punto') {
      _markers.add(Marker(
        markerId: const MarkerId("preview"),
        position: _puntosActuales.first,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ));
    } else if (_modoGeo == 'linea') {
      _polylines.add(Polyline(
        polylineId: const PolylineId("preview"),
        points: _puntosActuales,
        color: Colors.orange,
        width: 5,
      ));
    } else if (_modoGeo == 'poligono') {
      _polygons.add(Polygon(
        polygonId: const PolygonId("preview"),
        points: _puntosActuales,
        fillColor: Colors.orange.withOpacity(0.4),
        strokeColor: Colors.orange,
        strokeWidth: 2,
      ));
    }
  }

  // --- RECUPERACIÓN DE HISTORIAL ---

  void _cargarHistorial() async {
    final data = await DatabaseHelper.instance.obtenerGISPorHito(widget.hitoId);
    setState(() {
      _markers.clear(); _polylines.clear(); _polygons.clear();
      for (var g in data) {
        List<LatLng> coords = (jsonDecode(g['coordenadas']) as List)
            .map((e) => LatLng(e['lat'], e['lng'])).toList();
        final String id = "hist_${g['id']}";

        if (g['tipo_geo'] == 'punto') {
          _markers.add(Marker(markerId: MarkerId(id), position: coords.first, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure)));
        } else if (g['tipo_geo'] == 'linea') {
          _polylines.add(Polyline(polylineId: PolylineId(id), points: coords, color: Colors.blueGrey.withOpacity(0.5), width: 3));
        } else if (g['tipo_geo'] == 'poligono') {
          _polygons.add(Polygon(
            polygonId: PolygonId(id),
            points: coords,
            fillColor: Colors.blueGrey.withOpacity(0.2),
            strokeColor: Colors.blueGrey.withOpacity(0.5),
            strokeWidth: 2,
          ));
        }
      }
    });
  }

  Future<void> _determinarPosicionInicial() async {
    try {
      Position pos = await Geolocator.getCurrentPosition();
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 17));
    } catch (e) { _msg("GPS no disponible"); }
  }

  // --- MULTIMEDIA Y GUARDADO ---

  Future<void> _tomarFoto() async {
    final img = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 40);
    if (img != null) setState(() => _pathFoto = img.path);
  }

  Future<void> _gestionarAudio() async {
    if (await _audioRecorder.hasPermission()) {
      if (_isRecording) {
        final path = await _audioRecorder.stop();
        setState(() { _pathAudio = path; _isRecording = false; });
      } else {
        final dir = await Directory.systemTemp.createTemp();
        await _audioRecorder.start(const RecordConfig(), path: '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a');
        setState(() => _isRecording = true);
      }
    }
  }

  void _guardar() async {
    if (_puntosActuales.isEmpty) return;
    await DatabaseHelper.instance.insertarGeografia({
      'hito_id': widget.hitoId,
      'tipo_geo': _modoGeo,
      'descripcion': _descController.text.isEmpty ? "Levantamiento" : _descController.text,
      'coordenadas': jsonEncode(_puntosActuales.map((e) => {'lat': e.latitude, 'lng': e.longitude}).toList()),
      'fotografia': _pathFoto,
      'audio': _pathAudio,
    });
    setState(() { _puntosActuales.clear(); _pathFoto = null; _pathAudio = null; _descController.clear(); });
    _cargarHistorial();
    _msg("✅ Guardado con éxito");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("GIS PRECISIÓN"),
        actions: [
          PopupMenuButton<MapType>(
            icon: const Icon(Icons.layers_rounded),
            onSelected: (t) => setState(() => _currentMapType = t),
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: MapType.normal, child: Text("Normal")),
              const PopupMenuItem(value: MapType.satellite, child: Text("Satélite")),
              const PopupMenuItem(value: MapType.terrain, child: Text("Relieve")),
              const PopupMenuItem(value: MapType.hybrid, child: Text("Híbrido")),
            ],
          ),
          IconButton(icon: const Icon(Icons.check_circle, size: 30, color: Colors.greenAccent), onPressed: _guardar)
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(target: LatLng(0.2268, -78.2629), zoom: 17),
            mapType: _currentMapType,
            markers: _markers, polylines: _polylines, polygons: _polygons,
            onMapCreated: (c) => _mapController = c,
            onCameraMove: _onCameraMove,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          // --- NUEVO PUNTERO DE PRECISIÓN TOPOGRAFICA ---
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. Las 4 esquinas de encuadre
                const Icon(Icons.crop_free_rounded, size: 90, color: Colors.black87),
                // 2. Círculo exterior
                const Icon(Icons.panorama_fish_eye_rounded, size: 60, color: Colors.black87),
                // 3. Círculo interior
                const Icon(Icons.panorama_fish_eye_rounded, size: 35, color: Colors.black87),
                // 4. Cruz (+) con líneas finas
                const Icon(Icons.add, size: 45, color: Colors.black87, weight: 1),
                // 5. Punto central
                const Icon(Icons.fiber_manual_record, size: 6, color: Colors.black87),

                // Etiquetas de Coordenadas dinámicas

                Positioned(
                    left: 75,
                    width: 200,
                    child: Builder(
                      builder: (context) {
                        // 1. Convertimos Lat/Lng a UTM
                        // Otavalo/Mira está en la Zona 17 Norte (o Sur dependiendo de la línea equinoccial)
                        // El paquete detecta la zona automáticamente
                        final utm = UTM.fromLatLon(
                            lat: _mapCenter.latitude,
                            lon: _mapCenter.longitude
                        );
                        // Si latitud >= 0 es Norte, sino es Sur.
                        String hLabel = _mapCenter.latitude >= 0 ? "N" : "S";

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // X representa el Este (Easting) en metros
                            //_coordLabel("X: ${utm.easting.toStringAsFixed(2)} m"),
                            // Y representa el Norte (Northing) en metros
                            //_coordLabel("Y: ${utm.northing.toStringAsFixed(2)} m"),
                            // Información de Zona (Ej: 17N)
                            Text(
                              ": ${utm.zone}$hLabel",
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black87,
                                  letterSpacing: 1,
                                  shadows: [Shadow(color: Colors.white, blurRadius: 3)]
                              ),
                            ),

                          ],
                        );
                      },
                    )

                  /*
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                          "X: ${_mapCenter.longitude.toStringAsFixed(2)}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black, shadows: [Shadow(color: Colors.white, blurRadius: 4)])
                      ),
                      Text(
                          "Y: ${_mapCenter.latitude.toStringAsFixed(2)}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black, shadows: [Shadow(color: Colors.white, blurRadius: 4)])
                      ),
                    ],
                  ),
                  */


                ),
              ],
            ),
          ),

          // --- NUEVO PUNTERO DE PRECISIÓN (ESTILO MUESTRA ENVIADA) ---
          /*
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Círculo segmentado (simulado con icono de enfoque)
                const Icon(Icons.filter_center_focus, size: 70, color: Colors.black),
                // Cruz central (+)
                const Icon(Icons.add, size: 25, color: Colors.black, weight: 2),

                // Etiquetas de coordenadas X e Y
                Positioned(
                  left: 65,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                          "X: ${_mapCenter.longitude.toStringAsFixed(2)}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black, shadows: [Shadow(color: Colors.white, blurRadius: 2)])
                      ),
                      Text(
                          "Y: ${_mapCenter.latitude.toStringAsFixed(2)}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black, shadows: [Shadow(color: Colors.white, blurRadius: 2)])
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          */

          // BOTÓN FLOTANTE: CAPTURAR PUNTO BAJO LA MIRA
          Positioned(
            right: 20, top: MediaQuery.of(context).size.height / 2 - 30,
            child: FloatingActionButton(
              backgroundColor: const Color(0xFF1E293B),
              child: const Icon(Icons.ads_click, color: Colors.cyanAccent),
              onPressed: _agregarPuntoDePrecision,
            ),
          ),

          Positioned(top: 20, right: 15, child: FloatingActionButton.small(onPressed: _determinarPosicionInicial, child: const Icon(Icons.my_location))),

          // PANEL DE HERRAMIENTAS
          Positioned(
            bottom: 30, left: 15, right: 15,
            child: Card(
              elevation: 15, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _btnModo('punto', Icons.location_on),
                        _btnModo('linea', Icons.timeline),
                        _btnModo('poligono', Icons.pentagon_outlined),
                        const VerticalDivider(),
                        IconButton(icon: Icon(Icons.camera_alt, color: _pathFoto != null ? Colors.green : Colors.blueGrey), onPressed: _tomarFoto),
                        //IconButton(icon: Icon(_isRecording ? Icons.stop_circle : Icons.mic, color: _isRecording ? Colors.red : (_pathAudio != null ? Colors.green : Colors.blueGrey)), onPressed: _gestionarAudio),
                        IconButton(icon: const Icon(Icons.delete_sweep, color: Colors.redAccent), onPressed: () {
                          setState(() { _puntosActuales.clear(); _actualizarCapasVisuales(); });
                        }),
                      ],
                    ),
                    const Divider(),
                    TextField(
                      controller: _descController,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(hintText: "Descripción del detalle técnico...", border: InputBorder.none, icon: Icon(Icons.edit_note)),
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _btnModo(String m, IconData i) => IconButton(
    icon: Icon(i, color: _modoGeo == m ? Colors.orange : Colors.blueGrey, size: 30),
    onPressed: () => setState(() { _modoGeo = m; _puntosActuales.clear(); _actualizarCapasVisuales(); }),
  );


  // Esta función va al final de tu archivo
  Widget _coordLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 13,
        color: Colors.black,
        // La sombra blanca es vital para que el texto sea legible
        // tanto en mapas claros como en mapas satelitales oscuros.
        shadows: [
          Shadow(color: Colors.white, blurRadius: 4),
          Shadow(color: Colors.white, offset: Offset(1, 1)),
        ],
      ),
    );
  }


  void _msg(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t), behavior: SnackBarBehavior.floating));
}
