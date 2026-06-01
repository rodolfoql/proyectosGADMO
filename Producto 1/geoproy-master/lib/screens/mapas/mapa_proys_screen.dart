import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import '../../data/database_helper.dart';

class MapaProyectosScreen extends StatefulWidget {
  const MapaProyectosScreen({super.key});

  @override
  State<MapaProyectosScreen> createState() => _MapaProyectosScreenState();
}

class _MapaProyectosScreenState extends State<MapaProyectosScreen> {
  GoogleMapController? _mapController;
  MapType _currentMapType = MapType.normal;

  // Listas maestras para el motor de búsqueda en tiempo real
  List<Map<String, dynamic>> _listaProyectosCompleta = [];
  Set<Marker> _allMarkers = {};
  Set<Marker> _displayedMarkers = {};

  final _searchCtrl = TextEditingController();
  String _filtroBusqueda = "";

  final CameraPosition _initialPoint = const CameraPosition(
    target: LatLng(0.2268062, -78.2629038),
    zoom: 13,
  );

  @override
  void initState() {
    super.initState();
    _cargarProyectosEnMapa();
  }

  /// Recupera los proyectos analizando subtablas legales para definir el color del pin
  Future<void> _cargarProyectosEnMapa() async {
    final dbHelper = DatabaseHelper.instance;
    final db = await dbHelper.database;
    final proyectosRaw = await dbHelper.obtenerProyectos();

    Set<Marker> tempMarkers = {};
    List<Map<String, dynamic>> listaEnriquecida = [];

    for (var p in proyectosRaw) {
      if (p['coordenadas_maestras'] != null && p['coordenadas_maestras'].toString().isNotEmpty) {
        try {
          final Map<String, dynamic> coords = jsonDecode(p['coordenadas_maestras']);
          final double lat = coords['lat'];
          final double lng = coords['lng'];
          int proyId = p['id'] as int;

          // 1. Consultar subtablas en tiempo real para determinar el estado contractual real
          final List<Map<String, dynamic>> susp = await db.query('suspensiones', where: 'proyecto_id = ? AND estado = ?', whereArgs: [proyId, 'SUSPENDIDO']);
          final List<Map<String, dynamic>> multas = await db.query('multas', where: 'proyecto_id = ? AND estado = ?', whereArgs: [proyId, 'APLICADA']);

          String estadoCalculado = "EN EJECUCION";
          double tonalidadHue = BitmapDescriptor.hueGreen; // Verde por defecto

          if (p['alerta_atraso'] == 1) {
            estadoCalculado = "RETRASADO";
            tonalidadHue = BitmapDescriptor.hueRed; // Rojo
          }
          if (multas.isNotEmpty) {
            estadoCalculado = "CON MULTAS";
            tonalidadHue = BitmapDescriptor.hueOrange; // Naranja
          }
          if (susp.isNotEmpty) {
            estadoCalculado = "SUSPENDIDO";
            tonalidadHue = BitmapDescriptor.hueViolet; // Violeta / Gris de control
          }

          final Map<String, dynamic> proyectoProcesado = {
            ...p,
            'alerta_estado_gis': estadoCalculado,
          };
          listaEnriquecida.add(proyectoProcesado);

          tempMarkers.add(
            Marker(
              markerId: MarkerId(proyId.toString()),
              position: LatLng(lat, lng),
              icon: BitmapDescriptor.defaultMarkerWithHue(tonalidadHue),
              // Al pulsar el pin se dispara el panel inferior con los datos estilo formulario
              onTap: () => _desplegarFichaInformativaBottomSheet(proyectoProcesado),
            ),
          );
        } catch (e) {
          debugPrint("Error procesando punto GIS: $e");
        }
      }
    }

    setState(() {
      _listaProyectosCompleta = listaEnriquecida;
      _allMarkers = tempMarkers;
      _filtrarMarcadoresEnMapa();
    });
  }

  /// Filtra de forma inmediata los marcadores visibles en el mapa basándose en la RAM
  void _filtrarMarcadoresEnMapa() {
    if (_filtroBusqueda.isEmpty) {
      _displayedMarkers = Set.from(_allMarkers);
    } else {
      final List<String> idsFiltrados = _listaProyectosCompleta
          .where((p) => p['nombre'].toString().toLowerCase().contains(_filtroBusqueda.toLowerCase()))
          .map((p) => p['id'].toString())
          .toList();

      _displayedMarkers = _allMarkers.where((m) => idsFiltrados.contains(m.markerId.value)).toSet();
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Fichas y Coordenadas GIS", style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        actions: [
          PopupMenuButton<MapType>(
            icon: const Icon(Icons.layers_rounded),
            onSelected: (MapType type) => setState(() => _currentMapType = type),
            itemBuilder: (context) => [
              const PopupMenuItem(value: MapType.normal, child: Text("Vista Normal")),
              const PopupMenuItem(value: MapType.satellite, child: Text("Vista Satélite")),
              const PopupMenuItem(value: MapType.hybrid, child: Text("Vista Híbrida")),
            ],
          ),
          IconButton(icon: const Icon(Icons.sync_rounded), onPressed: _cargarProyectosEnMapa),
        ],
      ),
      body: Stack(
        children: [
          // CAPA PLANTA 1: MAPA SATELITAL / VECTORIAL
          GoogleMap(
            initialCameraPosition: _initialPoint,
            mapType: _currentMapType,
            markers: _displayedMarkers,
            onMapCreated: (GoogleMapController ctrl) => _mapController = ctrl,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            compassEnabled: true,
            zoomControlsEnabled: false,
          ),

          // CAPA PLANTA 2: CAJA DE BÚSQUEDA PREDICTIVA SUPERIOR FLOTANTE
          Positioned(
            top: 16, left: 16, right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 2))],
              ),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: "Buscar obra por nombre en Otavalo...",
                  hintStyle: const TextStyle(fontSize: 12),
                  prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                  suffixIcon: _filtroBusqueda.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() { _filtroBusqueda = ""; _filtrarMarcadoresEnMapa(); });
                    },
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (val) {
                  setState(() {
                    _filtroBusqueda = val.trim();
                    _filtrarMarcadoresEnMapa();
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
  // --- PANEL INFERIOR PREMIUM DETALLE ESTILO FORMULARIO ---
  void _desplegarFichaInformativaBottomSheet(Map<String, dynamic> proy) {
    String estado = proy['alerta_estado_gis'];

    Color colorSemaf;
    switch (estado) {
      case "SUSPENDIDO": colorSemaf = const Color(0xFF64748B); break;
      case "CON MULTAS": colorSemaf = const Color(0xFFF59E0B); break;
      case "RETRASADO": colorSemaf = const Color(0xFFEF4444); break;
      default: colorSemaf = const Color(0xFF10B981); // Verde ejecucion
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 45, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 15),

            // Fila de Cabecera: Nombre y Badge del Semáforo Contractual
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(proy['nombre'].toString().toUpperCase(), style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)))),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: colorSemaf, borderRadius: BorderRadius.circular(8)),
                  child: Text(estado, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const Divider(height: 25),

            // Campos de Fiscalización y Contrato Cruzados con tu Formulario
            _campoFormView(Icons.gavel, "Código Contractual:", "${proy['codigo_contrato'] ?? 'S/N'}"),
            _campoFormView(Icons.engineering, "Contratista Adjudicado:", "${proy['contratista'] ?? 'S/N'}"),
            _campoFormView(Icons.assignment_ind, "Fiscalizador de Obra:", "${proy['fiscalizador'] ?? 'S/N'}"),
            _campoFormView(Icons.near_me, "Ubicación Territorial:", "${proy['parroquia']} | ${proy['barrio'] ?? ''}"),
            _campoFormView(Icons.calendar_month, "Cronograma:", "Inicio: ${proy['fecha_inicio']} | Plazo Dinámico: ${proy['plazo_dinamico'] ?? proy['plazo']} días"),
            const SizedBox(height: 12),

            // Bloque Financiero en Celdas de Alta Visibilidad
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(15)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _celdaDinero("PRESUPUESTO", (proy['monto_total'] as num).toDouble()),
                  _celdaDinero("DEVENGADO", (proy['presupuesto_devengado'] as num).toDouble()),
                  _celdaDinero("SALDO DISP.", (proy['saldo'] as num).toDouble()),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Botón de Salto Directo a la Consola Operativa
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
              label: const Text("ABRIR FICHA COMPLETA DEL PROYECTO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/form_proyecto', arguments: proy).then((_) => _cargarProyectosEnMapa());
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _campoFormView(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(width: 6),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 11, color: Color(0xFF334155)))),
        ],
      ),
    );
  }

  Widget _celdaDinero(String label, double valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 2),
        Text("\$${valor.toStringAsFixed(2)}", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
      ],
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
}
