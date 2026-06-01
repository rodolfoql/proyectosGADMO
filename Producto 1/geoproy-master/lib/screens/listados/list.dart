import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import '../../data/database_helper.dart';
import '../../data/excel_service.dart';
import '../../data/excel_export_service.dart';
import 'widgets/widget_obra_card.dart'; // Ficha modular recursiva con niveles 2, 3 y 4

class ProjectListScreen extends StatefulWidget {
  const ProjectListScreen({super.key});

  @override
  State<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen> {
  List<Map<String, dynamic>> _proyectos = [];
  bool _isExporting = false;

  final _searchCtrl = TextEditingController();
  String _filtroBusqueda = "";

  int _paginaActual = 0;
  final int _limitePorPagina = 10;
  bool _tieneMasDatos = true;
  bool _isLoadingPages = false;

  @override
  void initState() {
    super.initState();
    _cargarPortafolio(reset: true);
  }

  /// Carga progresiva del inventario de obras aplicando consolidación financiera de subobras en caliente
  Future<void> _cargarPortafolio({bool reset = false, bool esRefrescoSilencioso = false}) async {
    if (_isLoadingPages) return;

    // CORRECCIÓN RADICAL: Si es un refresco por Checkbox, NO borramos la lista de la RAM
    if (reset && !esRefrescoSilencioso) {
      setState(() {
        _paginaActual = 0;
        _proyectos = [];
        _tieneMasDatos = true;
      });
    }

    setState(() => _isLoadingPages = true);
    final dbHelper = DatabaseHelper.instance;
    final db = await dbHelper.database;

    // =========================================================================
    // MODIFICACIÓN DE BÚSQUEDA INTELIGENTE EN CALIENTE (PADRES E HIJOS)
    // =========================================================================
    String whereClause = _filtroBusqueda.isEmpty ? "proyecto_padre_id IS NULL" : "nombre LIKE ?";
    List<dynamic> whereArgs = _filtroBusqueda.isEmpty ? [] : ['%$_filtroBusqueda%'];

    // CALCULO DE LÍMITES DINÁMICOS: Si es silencioso, lee todo el lote actual desde el inicio
    int limiteConsulta = esRefrescoSilencioso
        ? (_paginaActual * _limitePorPagina)
        : _limitePorPagina;

    int offsetConsulta = esRefrescoSilencioso ? 0 : (_paginaActual * _limitePorPagina);

    final List<Map<String, dynamic>> resRaw = await db.query(
      'proyectos',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'alerta_atraso DESC, id DESC',
      limit: limiteConsulta,
      offset: offsetConsulta,
    );

    List<Map<String, dynamic>> proyectosConTotales = [];

    // Tu algoritmo de consolidación financiera de subobras en tiempo real intacto
    for (var proy in resRaw) {
      int padreId = proy['id'] as int;

      final List<Map<String, dynamic>> subproyectos = await db.query(
        'proyectos',
        where: 'proyecto_padre_id = ?',
        whereArgs: [padreId],
      );

      if (subproyectos.isEmpty) {
        proyectosConTotales.add({
          ...proy,
          'tiene_hijos': false,
        });
      } else {
        double sumaMontoTotal = (proy['monto_total'] ?? 0).toDouble();
        double sumaDevengado = (proy['presupuesto_devengado'] ?? 0).toDouble();
        double sumaSaldo = (proy['saldo'] ?? 0).toDouble();
        int acumuladorPlazoTotal = proy['plazo_dinamico'] ?? proy['plazo'] ?? 0;
        int maxAlertaAtraso = proy['alerta_atraso'] ?? 0;

        for (var sub in subproyectos) {
          sumaMontoTotal += (sub['monto_total'] ?? 0).toDouble();
          sumaDevengado += (sub['presupuesto_devengado'] ?? 0).toDouble();
          sumaSaldo += (sub['saldo'] ?? 0).toDouble();
          acumuladorPlazoTotal += (sub['plazo_dinamico'] ?? sub['plazo'] ?? 0) as int;

          if (sub['alerta_atraso'] == 1) {
            maxAlertaAtraso = 1;
          }
        }

        double nuevoAvanceCalculado = sumaMontoTotal > 0 ? (sumaDevengado / sumaMontoTotal * 100) : 0.0;

        proyectosConTotales.add({
          ...proy,
          'monto_total': sumaMontoTotal,
          'presupuesto_devengado': sumaDevengado,
          'saldo': sumaSaldo,
          'plazo_dinamico': acumuladorPlazoTotal,
          'porcentaje_avance': nuevoAvanceCalculado,
          'alerta_atraso': maxAlertaAtraso,
          'tiene_hijos': true,
        });
      }
    }

    if (mounted) {
      setState(() {
        if (esRefrescoSilencioso) {
          // INTERCAMBIO EN CALIENTE: Sustituye los datos en la RAM manteniendo vivos los acordeones
          _proyectos = proyectosConTotales;
        } else {
          if (resRaw.length < _limitePorPagina) {
            _tieneMasDatos = false;
          }
          _proyectos.addAll(proyectosConTotales);
          _paginaActual++;
        }
        _isLoadingPages = false;
      });
    }
  }




  /*
  Future<void> _cargarPortafolio({bool reset = false}) async {
    if (_isLoadingPages) return;
    if (reset) {
      setState(() {
        _paginaActual = 0;
        _proyectos = [];
        _tieneMasDatos = true;
      });
    }

    setState(() => _isLoadingPages = true);
    final dbHelper = DatabaseHelper.instance;
    final db = await dbHelper.database;

    // =========================================================================
    // MODIFICACIÓN DE BÚSQUEDA INTELIGENTE EN CALIENTE (PADRES E HIJOS)
    // =========================================================================
    // Si la barra está vacía, la raíz solo muestra proyectos principales (Matrices).
    // Si el usuario escribe, eliminamos la restricción jerárquica para buscar en todo el universo local.
    String whereClause = _filtroBusqueda.isEmpty ? "proyecto_padre_id IS NULL" : "nombre LIKE ?";
    List<dynamic> whereArgs = _filtroBusqueda.isEmpty ? [] : ['%$_filtroBusqueda%'];

    int offset = _paginaActual * _limitePorPagina;

    final List<Map<String, dynamic>> resRaw = await db.query(
      'proyectos',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'alerta_atraso DESC, id DESC',
      limit: _limitePorPagina,
      offset: offset,
    );

    List<Map<String, dynamic>> proyectosConTotales = [];

    // Algoritmo de consolidación financiera de subobras en tiempo real
    for (var proy in resRaw) {
      int padreId = proy['id'] as int;

      // Consultamos si este proyecto tiene subproyectos (hijos) en el disco
      final List<Map<String, dynamic>> subproyectos = await db.query(
        'proyectos',
        where: 'proyecto_padre_id = ?',
        whereArgs: [padreId],
      );

      if (subproyectos.isEmpty) {
        // CASO A: Es una obra normal sin hijos (o un subproyecto suelto hallado por el buscador)
        proyectosConTotales.add({
          ...proy,
          'tiene_hijos': false,
        });
      } else {
        // CASO B: Es un Proyecto Padre. Sumamos algebraicamente los presupuestos de sus subobras.
        double sumaMontoTotal = (proy['monto_total'] ?? 0).toDouble();
        double sumaDevengado = (proy['presupuesto_devengado'] ?? 0).toDouble();
        double sumaSaldo = (proy['saldo'] ?? 0).toDouble();
        //int maxPlazoDinamico = proy['plazo_dinamico'] ?? proy['plazo'] ?? 0;
        int acumuladorPlazoTotal = proy['plazo_dinamico'] ?? proy['plazo'] ?? 0;
        int maxAlertaAtraso = proy['alerta_atraso'] ?? 0;

        for (var sub in subproyectos) {
          sumaMontoTotal += (sub['monto_total'] ?? 0).toDouble();
          sumaDevengado += (sub['presupuesto_devengado'] ?? 0).toDouble();
          sumaSaldo += (sub['saldo'] ?? 0).toDouble();

          // La duración del padre adopta el plazo dinámico de la ruta crítica (la subobra más larga)
          acumuladorPlazoTotal += (sub['plazo_dinamico'] ?? sub['plazo'] ?? 0) as int;
          /*
          int plazoSub = sub['plazo_dinamico'] ?? sub['plazo'] ?? 0;
          if (plazoSub > maxPlazoDinamico) {
            maxPlazoDinamico = plazoSub;
          }
          */

          if (sub['alerta_atraso'] == 1) {
            maxAlertaAtraso = 1;
          }
        }

        double nuevoAvanceCalculado = sumaMontoTotal > 0 ? (sumaDevengado / sumaMontoTotal * 100) : 0.0;

        proyectosConTotales.add({
          ...proy,
          'monto_total': sumaMontoTotal,
          'presupuesto_devengado': sumaDevengado,
          'saldo': sumaSaldo,
          //'plazo_dinamico': maxPlazoDinamico,
          'plazo_dinamico': acumuladorPlazoTotal,
          'porcentaje_avance': nuevoAvanceCalculado,
          'alerta_atraso': maxAlertaAtraso,
          'tiene_hijos': true,
        });
      }
    }

    if (mounted) {
      setState(() {
        if (resRaw.length < _limitePorPagina) {
          _tieneMasDatos = false;
        }
        _proyectos.addAll(proyectosConTotales);
        _paginaActual++;
        _isLoadingPages = false;
      });
    }
  }
  */

  /*
  Future<void> _cargarPortafolio({bool reset = false}) async {
    if (_isLoadingPages) return;
    if (reset) {
      setState(() {
        _paginaActual = 0;
        _proyectos = [];
        _tieneMasDatos = true;
      });
    }

    setState(() => _isLoadingPages = true);
    final dbHelper = DatabaseHelper.instance;
    final db = await dbHelper.database;

    // Filtramos para que el listado raíz muestre únicamente proyectos base (Matrices / Padres)
    String whereClause = "proyecto_padre_id IS NULL";
    List<dynamic> whereArgs = [];

    if (_filtroBusqueda.isNotEmpty) {
      whereClause += " AND nombre LIKE ?";
      whereArgs.add('%$_filtroBusqueda%');
    }

    int offset = _paginaActual * _limitePorPagina;

    final List<Map<String, dynamic>> resRaw = await db.query(
      'proyectos',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'alerta_atraso DESC, id DESC',
      limit: _limitePorPagina,
      offset: offset,
    );

    List<Map<String, dynamic>> proyectosConTotales = [];

    // Algoritmo de consolidación financiera bidireccional
    for (var proy in resRaw) {
      int padreId = proy['id'] as int;

      final List<Map<String, dynamic>> subproyectos = await db.query(
        'proyectos',
        where: 'proyecto_padre_id = ?',
        whereArgs: [padreId],
      );

      if (subproyectos.isEmpty) {
        // Obra independiente sin hijos asociados
        proyectosConTotales.add({
          ...proy,
          'tiene_hijos': false,
        });
      } else {
        // Proyecto Padre: Sumamos dinámicamente los presupuestos de sus subobras
        double sumaMontoTotal = (proy['monto_total'] ?? 0).toDouble();
        double sumaDevengado = (proy['presupuesto_devengado'] ?? 0).toDouble();
        double sumaSaldo = (proy['saldo'] ?? 0).toDouble();
        int maxPlazoDinamico = proy['plazo_dinamico'] ?? proy['plazo'] ?? 0;
        int maxAlertaAtraso = proy['alerta_atraso'] ?? 0;

        for (var sub in subproyectos) {
          sumaMontoTotal += (sub['monto_total'] ?? 0).toDouble();
          sumaDevengado += (sub['presupuesto_devengado'] ?? 0).toDouble();
          sumaSaldo += (sub['saldo'] ?? 0).toDouble();

          int plazoSub = sub['plazo_dinamico'] ?? sub['plazo'] ?? 0;
          if (plazoSub > maxPlazoDinamico) {
            maxPlazoDinamico = plazoSub;
          }

          if (sub['alerta_atraso'] == 1) {
            maxAlertaAtraso = 1;
          }
        }

        proyectosConTotales.add({
          ...proy,
          'monto_total': sumaMontoTotal,
          'presupuesto_devengado': sumaDevengado,
          'saldo': sumaSaldo,
          'plazo_dinamico': maxPlazoDinamico,
          'porcentaje_avance': sumaMontoTotal > 0 ? (sumaDevengado / sumaMontoTotal * 100) : 0.0,
          'alerta_atraso': maxAlertaAtraso,
          'tiene_hijos': true,
        });
      }
    }

    if (mounted) {
      setState(() {
        if (resRaw.length < _limitePorPagina) {
          _tieneMasDatos = false;
        }
        _proyectos.addAll(proyectosConTotales);
        _paginaActual++;
        _isLoadingPages = false;
      });
    }
  }
  */

  Future<void> _ejecutarExportacion() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> todosLosProyectos = await db.query('proyectos', orderBy: 'nombre ASC');

    if (todosLosProyectos.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("⚠️ No existen proyectos en el sistema para exportar."), behavior: SnackBarBehavior.floating)
        );
      }
      return;
    }

    int? proyectoSeleccionadoId;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Exportar Reporte Fiscal:", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: todosLosProyectos.length,
            itemBuilder: (c, i) => ListTile(
              leading: const Icon(Icons.analytics_rounded, color: Color(0xFF1E293B)),
              title: Text(todosLosProyectos[i]['nombre'].toString().toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              subtitle: Text("Código Contractual: ${todosLosProyectos[i]['codigo_contrato'] ?? 'S/N'}", style: const TextStyle(fontSize: 10)),
              onTap: () {
                proyectoSeleccionadoId = todosLosProyectos[i]['id'];
                Navigator.pop(ctx);
              },
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
        ],
      ),
    );

    if (proyectoSeleccionadoId == null) return;
    final int idSeleccionado = proyectoSeleccionadoId!;

    setState(() => _isExporting = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🚀 Generando reporte fiscal consolidado en Excel..."), behavior: SnackBarBehavior.floating)
      );
    }

    try {
      await ExcelExportService.exportarTodoElPortafolio(idSeleccionado);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ Archivo guardado con éxito y compartido"), behavior: SnackBarBehavior.floating)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("❌ Error al exportar: $e"), behavior: SnackBarBehavior.floating)
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        //leading: const Icon(Icons.inventory_2_rounded, color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.inventory_2_rounded, color: Colors.white),
          onPressed: () => Navigator.pushReplacementNamed(context, '/'),
        ),
        title: Text("Portafolio de Obras",
            style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1.1)),
        automaticallyImplyLeading: false,
        actions: [IconButton(onPressed: () => _cargarPortafolio(reset: true), icon: const Icon(Icons.sync))],
      ),
      body: Column(
        children: [
          // Barra superior de filtro predictivo en la RAM
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: "Buscar obra por nombre institucional...",
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                suffixIcon: _filtroBusqueda.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchCtrl.clear(); setState(() { _filtroBusqueda = ""; }); _cargarPortafolio(reset: true); })
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade200)),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (val) {
                setState(() { _filtroBusqueda = val.trim(); });
                _cargarPortafolio(reset: true);
              },
            ),
          ),

          Expanded(
            child: _proyectos.isEmpty && !_isLoadingPages
                ? const Center(child: Text("Sin registros en el sistema"))
                : NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification scrollInfo) {
                if (!_isLoadingPages && _tieneMasDatos && scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
                  _cargarPortafolio();
                }
                return true;
              },
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 10, bottom: 100),
                itemCount: _proyectos.length + (_tieneMasDatos ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _proyectos.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator(color: Color(0xFF1E293B))),
                    );
                  }
                  // INYECCIÓN PREMIUM DE LA FICHA MODULAR RECURSIVA TOTALIZADA
                  return WidgetObraCard(
                    proyecto: _proyectos[index],
                    //onRefreshRequired: () => _cargarPortafolio(reset: true),
                    onRefreshRequired: () => _cargarPortafolio(esRefrescoSilencioso: true),

                  );
                },
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomMasterMenu(),
    );
  }

  Widget _buildBottomMasterMenu() {
    return BottomAppBar(
      color: const Color(0xFF1E293B),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _barBtn(Icons.home_max_rounded, "Inicio", () => Navigator.pushReplacementNamed(context, '/')),
        _barBtn(Icons.file_open_outlined, "Importar", () => _importarRubros()),
        _barBtn(Icons.ios_share_rounded, "Exportar", () async => await _ejecutarExportacion()),
      ]),
    );
  }

  Widget _barBtn(IconData i, String l, VoidCallback t) => InkWell(
    onTap: t,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(i, color: Colors.white, size: 24),
      Text(l, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold))
    ]),
  );


  // --- RECONSTRUCCIÓN COMPLETA DEL SELECTOR MASIVO DE IMPORTACIÓN ---
  Future<void> _importarRubros() async {
    final db = await DatabaseHelper.instance.database;

    final List<Map<String, dynamic>> todosLosProyectosSinc = await db.query(
    'proyectos',
    orderBy: 'nombre ASC'
    );

    if (todosLosProyectosSinc.isEmpty) {
    if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("⚠️ No existen obras en el sistema para importar rubros."), behavior: SnackBarBehavior.floating)
    );
    }
    return;
    }

    int? proyectoSeleccionado;

    if (!mounted) return;

    await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
    title: const Text("Importar Presupuesto a:", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
    content: SizedBox(
    width: double.maxFinite,
    height: 300,
    child: ListView.builder(
    shrinkWrap: true,
    itemCount: todosLosProyectosSinc.length,
    itemBuilder: (c, i) {
    final proy = todosLosProyectosSinc[i];
    final bool esSubobra = proy['proyecto_padre_id'] != null;

    return ListTile(
    dense: true,
    leading: Icon(
    esSubobra ? Icons.subdirectory_arrow_right_rounded : Icons.apartment,
    color: esSubobra ? Colors.cyan : const Color(0xFF1E293B),
    size: esSubobra ? 18 : 22,
    ),
    title: Text(
    proy['nombre'].toString().toUpperCase(),
    style: TextStyle(
    fontSize: 11,
    fontWeight: esSubobra ? FontWeight.normal : FontWeight.bold,
    color: esSubobra ? Colors.black87 : const Color(0xFF1E293B)
    )
    ),
    subtitle: Text(
    esSubobra ? "↳ Subobra / Dependencia" : "Obra Principal Matriz",
    style: const TextStyle(fontSize: 9, color: Colors.grey),
    ),
    onTap: () {
    proyectoSeleccionado = proy['id'];
    Navigator.pop(ctx);
    }
    );
    }
    ),
    ),
    actions: [
    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
    ],
    ),
    );

    if (proyectoSeleccionado == null) return;

    var status = await Permission.manageExternalStorage.request();
    if (!status.isGranted) status = await Permission.storage.request();

    if (status.isGranted) {
    _abrirExploradorDinamicamente('/storage/emulated/0', proyectoSeleccionado!);
    } else {
    if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("❌ Permiso denegado. Active el acceso a archivos."), behavior: SnackBarBehavior.floating)
    );
    }
    }
  }

  /*
  Future<void> _importarRubros() async {
    if (_proyectos.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("⚠️ Cree un proyecto antes de importar rubros desde Excel"), behavior: SnackBarBehavior.floating)
        );
      }
      return;
    }
    int? proyectoSeleccionado;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: const Text("Importar a Proyecto:", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        content: SizedBox(width: double.maxFinite, child: ListView.builder(shrinkWrap: true, itemCount: _proyectos.length, itemBuilder: (c, i) => ListTile(leading: const Icon(Icons.apartment, color: Color(0xFF1E293B)), title: Text(_proyectos[i]['nombre'], style: const TextStyle(fontSize: 12)), onTap: () { proyectoSeleccionado = _proyectos[i]['id']; Navigator.pop(ctx); }))),
      ),
    );
    if (proyectoSeleccionado == null) return;

    // Verificación defensiva de permisos de acceso a archivos en Android 13/14
    var status = await Permission.manageExternalStorage.request();
    if (!status.isGranted) status = await Permission.storage.request();

    if (status.isGranted) {
      _abrirExploradorDinamicamente('/storage/emulated/0', proyectoSeleccionado!);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("❌ Permiso denegado. Active el acceso a archivos en los ajustes."), behavior: SnackBarBehavior.floating)
        );
      }
    }
  }
  */

  // RECONSTRUCCIÓN VERIFICADA: Navegador físico en carpetas para archivos de presupuesto .xlsx
  void _abrirExploradorDinamicamente(String path, int proyectoId) async {
    final directory = Directory(path);
    List<FileSystemEntity> entities = [];
    try {
      entities = directory.listSync();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Acceso restringido a esta carpeta"), behavior: SnackBarBehavior.floating));
      }
      return;
    }

    List<FileSystemEntity> filtered = entities.where((f) {
      final name = f.path.split('/').last;
      if (name.startsWith('.')) return false;
      if (FileSystemEntity.isDirectorySync(f.path)) return true;
      return f.path.toLowerCase().endsWith('.xlsx');
    }).toList();

    filtered.sort((a, b) {
      bool aDir = FileSystemEntity.isDirectorySync(a.path);
      bool bDir = FileSystemEntity.isDirectorySync(b.path);
      if (aDir && !bDir) return -1;
      if (!aDir && bDir) return 1;
      return a.path.toLowerCase().compareTo(b.path.toLowerCase());
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 15),
            Text("Seleccionar Presupuesto Masivo", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
            const Divider(),
            if (path != '/storage/emulated/0') ListTile(leading: const Icon(Icons.arrow_back_ios_new, size: 18), title: const Text("Regresar"), onTap: () { Navigator.pop(ctx); _abrirExploradorDinamicamente(directory.parent.path, proyectoId); }),
            Expanded(child: ListView.builder(
                controller: scrollController,
                itemCount: filtered.length,
                itemBuilder: (c, i) {
                  final item = filtered[i];
                  bool isDir = FileSystemEntity.isDirectorySync(item.path);
                  String name = item.path.split('/').last;
                  return ListTile(
                      leading: Icon(isDir ? Icons.folder : Icons.table_chart, color: isDir ? Colors.amber : Colors.green),
                      title: Text(name, style: TextStyle(fontSize: 12, fontWeight: isDir ? FontWeight.bold : FontWeight.normal)),
                      onTap: () async {
                        if (isDir) {
                          Navigator.pop(ctx);
                          _abrirExploradorDinamicamente(item.path, proyectoId);
                        } else {
                          Navigator.pop(ctx);
                          if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚙️ Procesando celdas del presupuesto..."), behavior: SnackBarBehavior.floating)); }

                          // Invocación síncrona del servicio importador de Excel con homologación SERCOP
                          bool ok = await ExcelImportService.importarPresupuesto(item.path, proyectoId);
                          if (ok) {
                            _cargarPortafolio(reset: true);
                            if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Importación Exitosa"), behavior: SnackBarBehavior.floating)); }
                          } else {
                            if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("❌ Error en formato de Excel o unidades"), behavior: SnackBarBehavior.floating)); }
                          }
                        }
                      }
                  );
                }
            )),
          ]),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
} // <--- FIN DE LA CLASE STATE DEL PORTAFOLIO DE OBRAS
