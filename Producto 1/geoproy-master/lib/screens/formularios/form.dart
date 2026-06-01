import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import '../../data/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FormularioObra extends StatefulWidget {
  final dynamic arguments;
  const FormularioObra({super.key, this.arguments});

  @override
  // CORRECCIÓN SINTÁCTICA: Retorno tipado estrictamente como State para solucionar el error
  State<FormularioObra> createState() => _FormularioObraState();
}

class _FormularioObraState extends State<FormularioObra> {
  final _formKey = GlobalKey<FormState>();

  // --- CONTROLADORES PROYECTO ORIGINALES ---
  final _nomCtrl = TextEditingController();
  final _inicioCtrl = TextEditingController();
  final _plazoCtrl = TextEditingController();
  final _contCtrl = TextEditingController();
  final _admCtrl = TextEditingController();
  final _socialCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();
  final _cantonCtrl = TextEditingController(text: "OTAVALO");
  final _parroquiaCtrl = TextEditingController();
  final _barrioCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();

  // --- VERIFICACIÓN TÉCNICA: CONTROLADORES DE FISCALIZACIÓN Y SERCOP ---
  final _sercopCtrl = TextEditingController();
  final _fiscCtrl = TextEditingController();
  final _codContratoCtrl = TextEditingController();

  // Coordenadas Maestras (Defecto Otavalo)
  LatLng _selectedLocation = const LatLng(0.2268062, -78.2629038);
  String _coordLabel = "0.2268, -78.2629 (Por defecto)";

  // --- CONTROLADORES HITO ORIGINALES ---
  final _rubroNumCtrl = TextEditingController();
  final _unidadCtrl = TextEditingController();
  final _cantidadCtrl = TextEditingController();
  final _precioUnitCtrl = TextEditingController();

  // --- LISTADOS ESTRICTOS DE SELECCIÓN ---
  final List<String> _parroquiasOtavalo = [
    'SELVA ALEGRE', 'PATAQUI', 'SAN JOSE DE QUICHINCHE', 'SAN PABLO',
    'GONZALEZ SUAREZ', 'SAN RAFAEL', 'SAN JUAN DE ILUMAN',
    'DOCTOR MIGUEL EGAS CABEZAS', 'EUGENIO ESPEJO', 'EL JORDAN URBANO',
    'EL JORDAN RURAL', 'SAN LUIS URBANO', 'SAN LUIS RURAL', 'OTAVALO'
  ];

  final List<String> _unidadesSercop = ['u', 'kg', 'm', 'm2', 'm3', 'ml', 'jgo', 'glb', 'km', 'pto', 'Ha'];

  // Catálogo de Obras en disco para la Selección Jerárquica Recursiva
  List<Map<String, dynamic>> _proyectosPadres = [];

  String _categoria = 'VIA', _prioridad = 'MEDIA';
  bool _isEditing = false, _isHito = false;

  int _plazoMaximoProyecto = 0;
  int? _proyectoPadreId;

  @override
  void initState() {
    super.initState();
    _procesarContexto();
  }

  /// Carga de SQLite la lista de obras elegibles como matrices excluyendo la actual (Evita bucles infinitos)
  Future<void> _cargarProyectosPadresDisponibles(int? proyectoActualId) async {
    final db = await DatabaseHelper.instance.database;
    List<Map<String, dynamic>> lista;

    if (proyectoActualId != null) {
      lista = await db.query('proyectos', where: 'id != ?', whereArgs: [proyectoActualId], orderBy: 'nombre ASC');
    } else {
      lista = await db.query('proyectos', orderBy: 'nombre ASC');
    }

    setState(() {
      _proyectosPadres = lista;
    });
  }

  void _procesarContexto() async {
    final args = widget.arguments;
    int? currentProyId;

    if (args is Map<String, dynamic>) {
      _isHito = args.containsKey('grupo_id');

      if (args.containsKey('proyecto_padre_id')) {
        _proyectoPadreId = args['proyecto_padre_id'];
      }

      if (_isHito) {
        final db = await DatabaseHelper.instance.database;
        final List<Map<String, dynamic>> p = await db.query(
            'proyectos',
            where: 'id = ?',
            whereArgs: [args['proyecto_id']]
        );
        if (p.isNotEmpty) {
          _plazoMaximoProyecto = p.first['plazo'] as int;
        }
      }

      // 1. CASO EDICIÓN DETECTADO
      if (args.containsKey('id')) {
        _isEditing = true;
        if (!_isHito) {
          currentProyId = args['id'];
          _nomCtrl.text = (args['nombre'] ?? "").toString();
          _contCtrl.text = (args['contratista'] ?? "").toString();
          _montoCtrl.text = (args['monto_total'] ?? 0).toString();
          _plazoCtrl.text = (args['plazo'] ?? 0).toString();
          _inicioCtrl.text = (args['fecha_inicio'] ?? "").toString();
          _admCtrl.text = (args['administrador_contrato'] ?? "").toString();
          _socialCtrl.text = (args['contacto_comunidad'] ?? "").toString();
          _cantonCtrl.text = (args['canton'] ?? "OTAVALO").toString();
          _parroquiaCtrl.text = (args['parroquia'] ?? "").toString();
          _barrioCtrl.text = (args['barrio'] ?? "").toString();
          _obsCtrl.text = (args['observacion'] ?? "").toString();
          _categoria = args['categoria_obra'] ?? 'VIA';
          _prioridad = args['prioridad'] ?? 'MEDIA';

          _proyectoPadreId = args['proyecto_padre_id'];

          // Inyección de los campos incrementados en el cargador de edición
          _sercopCtrl.text = (args['url_sercop'] ?? "").toString();
          _fiscCtrl.text = (args['fiscalizador'] ?? "").toString();
          _codContratoCtrl.text = (args['codigo_contrato'] ?? "").toString();

          if (args['coordenadas_maestras'] != null && args['coordenadas_maestras'].toString().isNotEmpty) {
            var decoded = jsonDecode(args['coordenadas_maestras']);
            _selectedLocation = LatLng(decoded['lat'], decoded['lng']);
            _coordLabel = "${_selectedLocation.latitude.toStringAsFixed(6)}, ${_selectedLocation.longitude.toStringAsFixed(6)}";
          }
        } else {
          setState(() {
            _rubroNumCtrl.text = (args['rubro'] ?? "").toString();
            _nomCtrl.text = (args['descripcion'] ?? "").toString();
            _unidadCtrl.text = (args['unidad'] ?? "").toString();
            _cantidadCtrl.text = (args['cantidad'] ?? 0).toString();
            _precioUnitCtrl.text = (args['precio_unitario'] ?? 0).toString();
            _plazoCtrl.text = (args['plazo'] ?? 0).toString();
            _inicioCtrl.text = (args['fecha_inicio'] ?? "").toString();
          });
        }
      }
      // 2. CASO NUEVO HITO
      else if (_isHito) {
        final db = await DatabaseHelper.instance.database;
        final List<Map<String, dynamic>> p = await db.query('proyectos', where: 'id = ?', whereArgs: [args['proyecto_id']]);
        if (p.isNotEmpty) {
          setState(() {
            _inicioCtrl.text = p.first['fecha_inicio'];
            _plazoCtrl.text = _plazoMaximoProyecto.toString();
          });
        }
      } else {
        if (_parroquiaCtrl.text.isEmpty) _parroquiaCtrl.text = _parroquiasOtavalo.first;
      }
    } else {
      _inicioCtrl.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (_parroquiaCtrl.text.isEmpty) _parroquiaCtrl.text = _parroquiasOtavalo.first;
    }

    if (!_isHito) {
      await _cargarProyectosPadresDisponibles(currentProyId);
    }
  }
  Future<void> _obtenerGPS() async {
    bool serviceEnabled;
    LocationPermission permission;
    const double defLat = 0.2268062;
    const double defLng = -78.2629038;
    _msg("📍 Localizando dispositivo...");

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _asignarCoordenadas(defLat, defLng, "0.2268, -78.2629 (GPS Apagado)");
        return;
      }
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _asignarCoordenadas(defLat, defLng, "0.2268, -78.2629 (Sin Permiso)");
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _asignarCoordenadas(defLat, defLng, "0.2268, -78.2629 (Permiso Bloqueado)");
        return;
      }
      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _asignarCoordenadas(pos.latitude, pos.longitude, "${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}");
    } catch (e) {
      _asignarCoordenadas(defLat, defLng, "0.2268, -78.2629 (Error técnico)");
    }
  }

  void _asignarCoordenadas(double lat, double lng, String label) {
    setState(() {
      _selectedLocation = LatLng(lat, lng);
      _coordLabel = label;
    });
    _msg(lat == 0.2268062 ? "⚠️ Usando ubicación por defecto" : "✅ Ubicación capturada");
  }

  void _seleccionarEnMapa() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Seleccione el punto de obra", style: TextStyle(fontSize: 14)),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(target: _selectedLocation, zoom: 14),
            onTap: (LatLng point) {
              setState(() {
                _selectedLocation = point;
                _coordLabel = "${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}";
              });
              Navigator.pop(ctx);
              _msg("📍 Ubicación asignada por mapa");
            },
            markers: { Marker(markerId: const MarkerId("sel"), position: _selectedLocation) },
          ),
        ),
      ),
    );
  }

  void _guardar() async {
    if (_formKey.currentState!.validate()) {
      final db = DatabaseHelper.instance;
      final args = widget.arguments;

      // 1. CAPTURA AUTOMÁTICA DEL USUARIO LOGUEADO DESDE PREFERENCES
      final prefs = await SharedPreferences.getInstance();
      String? rawUserData = prefs.getString('userData');
      String usuarioIdLogueado = "0"; // Valor de respaldo preventivo

      if (rawUserData != null) {
        try {
          var userMap = jsonDecode(rawUserData);
          // Odoo e inputs guardan el identificador del ciudadano/técnico bajo la llave 'id'
          usuarioIdLogueado = (userMap['id'] ?? "0").toString();
        } catch (e) {
          debugPrint("Error al decodificar usuario en auditoría: $e");
        }
      }

      if (_isHito) {
        Map<String, dynamic> data = {
          'grupo_id': args['grupo_id'],
          'rubro': _rubroNumCtrl.text,
          'descripcion': _nomCtrl.text,
          'unidad': _unidadCtrl.text,
          'cantidad': double.parse(_cantidadCtrl.text),
          'precio_unitario': double.parse(_precioUnitCtrl.text),
          'fecha_inicio': _inicioCtrl.text,
          'plazo': int.parse(_plazoCtrl.text),
          // Opcional: Si quieres registrar qué fiscalizador creó el hito específico
          'elaborado_por': usuarioIdLogueado,
        };
        if (_isEditing) await db.actualizarHito(args['id'], data, args['proyecto_id']);
        else await db.insertarHito(data, args['proyecto_id']);
      } else {
        // VERIFICACIÓN DE MAPEO: Poblamiento de campos requeridos para control técnico dinámico
        Map<String, dynamic> data = {
          'proyecto_padre_id': _proyectoPadreId,
          'nombre': _nomCtrl.text,
          'contratista': _contCtrl.text,
          'monto_total': double.parse(_montoCtrl.text),
          'plazo': int.parse(_plazoCtrl.text),
          'fecha_inicio': _inicioCtrl.text,
          'administrador_contrato': _admCtrl.text,
          'contacto_comunidad': _socialCtrl.text,
          'prioridad': _prioridad,
          'categoria_obra': _categoria,
          'canton': _cantonCtrl.text,
          'parroquia': _parroquiaCtrl.text,
          'barrio': _barrioCtrl.text,
          'observacion': _obsCtrl.text,
          'coordenadas_maestras': jsonEncode({"lat": _selectedLocation.latitude, "lng": _selectedLocation.longitude}),

          // Mapeo físico verificado de campos Sercop y Fiscalizador
          'url_sercop': _sercopCtrl.text.trim(),
          'fiscalizador': _fiscCtrl.text.trim(),
          'codigo_contrato': _codContratoCtrl.text.trim(),
          'elaborado_por': usuarioIdLogueado,
        };
        if (_isEditing) await db.actualizarProyecto(args['id'], data);
        else await db.insertarProyecto(data);
      }
      Navigator.pop(context, true);
    }
  }

  Future<void> _seleccionarFecha(BuildContext context, TextEditingController controller) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        controller.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    String titulo = _isHito ? (_isEditing ? "Editar Hito" : "Nuevo Hito") : (_isEditing ? "Ficha de Proyecto" : "Nueva Obra");
    if (!_isHito && _proyectoPadreId != null) titulo = _isEditing ? "Editar Subproyecto" : "Nuevo Subproyecto";

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: Text(titulo)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (!_isHito) ..._buildProyectoUI(),
            if (_isHito) ..._buildHitoUI(),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: _guardar,
              child: const Text("GUARDAR REGISTRO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildProyectoUI() {
    return [
    _sectionHeader("Geolocalización del Proyecto"),
    Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
    child: Column(children: [
    Text("Ubicación: $_coordLabel", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo)),
    const SizedBox(height: 10),
    Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
    ElevatedButton.icon(onPressed: _obtenerGPS, icon: const Icon(Icons.gps_fixed, size: 16), label: const Text("GPS")),
    ElevatedButton.icon(onPressed: _seleccionarEnMapa, icon: const Icon(Icons.map, size: 16), label: const Text("MAPA")),
    ])
    ]),
    ),

    _sectionHeader("Jerarquía de la Obra (Estructura)"),
    // VERIFICACIÓN COMPLETA: Dropdown relacional dinámico para Proyecto Padre
    Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<int?>(
    value: _proyectosPadres.any((p) => p['id'] == _proyectoPadreId) ? _proyectoPadreId : null,
    decoration: InputDecoration(
    labelText: "Proyecto Matriz / Padre (Vacío si es Obra Principal)",
    prefixIcon: const Icon(Icons.account_tree_outlined, size: 20),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    items: [
    const DropdownMenuItem<int?>(
    value: null,
    child: Text("NINGUNO (Es Obra Principal Base)", style: TextStyle(fontSize: 13, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
    ),
    ..._proyectosPadres.map((p) {
    return DropdownMenuItem<int?>(
    value: p['id'] as int,
    child: Text(
    p['nombre'].toString().toUpperCase(),
    style: const TextStyle(fontSize: 12),
    ),
    );
    }),
    ],
    onChanged: (int? nuevoId) {
    setState(() => _proyectoPadreId = nuevoId);
    },
    ),
    ),

    _sectionHeader("Identificación y Contrato"),
    _input(_nomCtrl, "Nombre del Proyecto o Subobra", Icons.work, required: true),
    _input(_contCtrl, "Contratista Adjudicado", Icons.engineering, required: true),

    // VERIFICACIÓN COMPLETA: Despliegue de los campos incrementados de control legal SERCOP
    _input(_codContratoCtrl, "Código de Contrato Municipal", Icons.gavel, required: true),
    _input(_fiscCtrl, "Nombre del Fiscalizador Asignado", Icons.assignment_ind, required: true),
    _input(_sercopCtrl, "Enlace Web del Proceso SERCOP (URL)", Icons.language, required: false),

    _dropdown(['VIA', 'AREA', 'PUNTO'], _categoria, "Tipo de Obra", (v) => setState(() => _categoria = v!)),
      _sectionHeader("Social y Admin (Opcional)"),
      _input(_admCtrl, "Administrador de Contrato", Icons.person, required: false),
      _input(_socialCtrl, "Contacto Comunidad", Icons.people, required: false),
      _input(_obsCtrl, "Observaciones", Icons.comment, required: false, maxLines: 2),

      _sectionHeader("Ubicación Territorial"),
      Row(children: [
        //Expanded(child: _input(_cantonCtrl, "Cantón", Icons.map, required: true, habilitado: false)),
        //const SizedBox(width: 10),
        Expanded(
          child: _dropdown(_parroquiasOtavalo, _parroquiaCtrl.text.isEmpty ? _parroquiasOtavalo.first : _parroquiaCtrl.text, "Parroquia", (v) {
            setState(() => _parroquiaCtrl.text = v!);
          }),
        ),
      ]),
      _input(_barrioCtrl, "Barrio / Comunidad", Icons.home, required: true),
      _sectionHeader("Presupuesto y Cronograma Contractual"),
      Row(children: [
        Expanded(child: _input(_montoCtrl, "Monto \$", Icons.payments, isNum: true, required: true)),
        const SizedBox(width: 10),
        Expanded(child: _input(_plazoCtrl, "Plazo Original (Días)", Icons.timer, isNum: true, required: true)),
      ]),
      _input(_inicioCtrl, "Fecha Inicio (AAAA-MM-DD)", Icons.calendar_today, required: true, isDate: true),
    ];
  }

  List<Widget> _buildHitoUI() {
    return [
      _sectionHeader("Detalle del hito"),
      _input(_rubroNumCtrl, "Cód. hito / CPC", Icons.numbers, required: true),
      _input(_nomCtrl, "Descripción de la actividad", Icons.description, required: true),
      Row(children: [
        Expanded(
          child: _dropdown(_unidadesSercop, _unidadCtrl.text.isEmpty ? _unidadesSercop.first : _unidadCtrl.text, "Unidad", (v) {
            setState(() => _unidadCtrl.text = v!);
          }),
        ),
        const SizedBox(width: 10),
        Expanded(child: _input(_cantidadCtrl, "Cantidad Planificada", Icons.add_chart, isNum: true, required: true)),
      ]),
      _input(_precioUnitCtrl, "Precio Unitario \$", Icons.monetization_on, isNum: true, required: true),
      _sectionHeader("Cronograma del Hito"),
      _input(_inicioCtrl, "Fecha Inicio", Icons.calendar_today, required: true, isDate: true),
      _input(_plazoCtrl, "Plazo Ejecución (Días)", Icons.timer, isNum: true, required: true, isPlazoHito: true),
    ];
  }

  Widget _sectionHeader(String t) => Padding(padding: const EdgeInsets.only(top: 20, bottom: 8), child: Text(t.toUpperCase(), style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.blueGrey)));

  Widget _input(TextEditingController c, String l, IconData i, {bool isNum = false, bool isDate = false, int maxLines = 1, required bool required, bool isPlazoHito = false, bool habilitado = true}) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
          controller: c,
          maxLines: maxLines,
          enabled: habilitado,
          readOnly: isDate,
          onTap: isDate ? () => _seleccionarFecha(context, c) : null,
          keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          decoration: InputDecoration(
            labelText: l,
            prefixIcon: Icon(i, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            helperText: isPlazoHito ? "Rango permitido: 1 a $_plazoMaximoProyecto días" : null,
            filled: !habilitado || isDate,
            fillColor: (!habilitado || isDate) ? const Color(0xFFF1F5F9) : null,
          ),
          validator: (v) {
            if (required && (v == null || v.trim().isEmpty)) return "Obligatorio";
            if (isNum && v != null && v.isNotEmpty && double.tryParse(v) == null) return "Número inválido";
            if (isPlazoHito && v != null && v.isNotEmpty) {
              int? dias = int.tryParse(v);
              if (dias == null) return "Número inválido";
              if (dias > _plazoMaximoProyecto) return "⚠️ Excede el plazo del proyecto ($_plazoMaximoProyecto)";
              if (dias <= 0) return "Debe ser mayor a 0";
            }
            return null;
          }
      )
  );

  Widget _dropdown(List<String> items, String val, String l, Function(String?) onChanged) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
          value: items.contains(val) ? val : items.first,
          decoration: InputDecoration(labelText: l, prefixIcon: const Icon(Icons.list_alt, size: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: onChanged
      )
  );

  void _msg(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t), behavior: SnackBarBehavior.floating));

  @override
  void dispose() {
    _nomCtrl.dispose(); _inicioCtrl.dispose(); _plazoCtrl.dispose();
    _contCtrl.dispose(); _admCtrl.dispose(); _socialCtrl.dispose();
    _montoCtrl.dispose(); _cantonCtrl.dispose(); _parroquiaCtrl.dispose();
    _barrioCtrl.dispose(); _obsCtrl.dispose(); _rubroNumCtrl.dispose();
    _unidadCtrl.dispose(); _cantidadCtrl.dispose(); _precioUnitCtrl.dispose();
    _sercopCtrl.dispose(); _fiscCtrl.dispose(); _codContratoCtrl.dispose(); // Cierre preventivo
    super.dispose();
  }
}
