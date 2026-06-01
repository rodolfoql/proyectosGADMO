import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/api_webservice.dart';
import '../data/database_helper.dart';
import 'dart:io';
import 'dart:async';
import '../data/config_webservice.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSyncing = false;
  int _alertasCriticas = 0;
  double _ejecucionGlobal = 0.0;
  int _currentIndex = 0;

  // Paleta de colores extraída de la imagen de referencia
  final Color azulFondo = const Color(0xFF1E3A8A);
  final Color azulInicio = const Color(0xFF3B82F6);
  final Color cianFin = const Color(0xFF06B6D4);
  final Color grisMenu = const Color(0xFFF1F5F9);
  //PALETA PARA GADMO
  final Color azulMuestraInicio = const Color(0xFF1A237E); // Azul Marino Profundo
  final Color azulMuestraFin = const Color(0xFF0D47A1);

  // 1. Agrega estas dos nuevas variables arriba en tu clase State:
  String _nombreUsuario = "Fiscalizador";
  String _fotoBase64 = "";




  // FUNCIÓN PARA QUITAR CONTROLES (Barras de sistema)
  void _activarModoInmersivo() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky, // Oculta barras y reaparecen al deslizar
    );
  }

  @override
  void initState() {
    super.initState();
    _activarModoInmersivo(); // Activar al iniciar
    _cargarResumenEjecutivo();

    /*
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    */
  }

  Future<void> _cargarResumenEjecutivo() async {
    final prefs = await SharedPreferences.getInstance();
    String? rawUserData = prefs.getString('userData');
    if (rawUserData != null) {
      var userMap = jsonDecode(rawUserData);
      setState(() {
        _nombreUsuario = (userMap['name'] ?? "Fiscalizador").toString();
        _fotoBase64 = (userMap['f_ciuimag'] ?? "").toString(); // Captura el string de la foto
      });
    }

    try {
      final proyectos = await DatabaseHelper.instance.obtenerProyectos();
      double totalMonto = 0, totalDevengado = 0;
      int alertas = 0;

      for (var p in proyectos) {
        totalMonto += (p['monto_total'] ?? 0).toDouble();
        totalDevengado += (p['presupuesto_devengado'] ?? 0).toDouble();
        if (p['alerta_atraso'] == 1) alertas++;
      }

      if (mounted) {
        setState(() {
          _alertasCriticas = alertas;
          _ejecucionGlobal = totalMonto > 0 ? (totalDevengado / totalMonto) : 0.0;
        });
      }
    } catch (e) {
      // Error al leer la base de datos local
      if (mounted) {
        _mostrarErrorDialog("Error al cargar resumen local", e.toString());
      }
    }
  }


  void _sincronizarConOdoo() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    try {
      final resultado = await ApiService().sincronizarBidireccional();

      if (resultado['success']) {
        // 1. Recargar datos locales para actualizar el resumen ejecutivo y la lista
        await _cargarResumenEjecutivo();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Sincronización finalizada correctamente"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        _mostrarErrorDialog("Error de Sincronización", resultado['message']);
      }
    } catch (e) {
      _mostrarErrorDialog("Error Crítico", e.toString());
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }


  void _mostrarErrorDialog(String titulo, String error) {
    showDialog(
      context: context,
      barrierDismissible: false, // Obliga al usuario a cerrar el diálogo
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 10),
            Expanded(child: Text(titulo, style: const TextStyle(color: Colors.red, fontSize: 18))),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Detalle técnico:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SelectableText(
                  error, // Permite copiar el error si es necesario
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CERRAR"),
          ),
        ],
      ),
    );
  }







  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF0F9FF), Colors.white],
          ),
        ),
        child: _currentIndex == 0 ? _buildMainPanel() : _buildCreditsPage(),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildMainPanel() {
    return Column( // Cambiamos SingleChildScrollView por Column para fijar el Header
      children: [
        _buildHeader(), // El Header se queda fijo arriba porque está fuera del Scroll
        Expanded(
          child: SingleChildScrollView( // Solo este bloque tendrá desplazamiento
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 15),
                  _buildCompactMetrics(),

                  const SizedBox(height: 25),
                  _buildSectionLabel("GESTIÓN OPERATIVA"),
                  const SizedBox(height: 15),
                  _buildMainMenuGrid(),

                  const SizedBox(height: 30),
                  _buildSectionLabel("VISUALIZACIÓN GEOGRÁFICA"),
                  const SizedBox(height: 15),
                  _buildWideActionCard("Mapeo de Proyectos", "Mapeo global de proyectos", Icons.map_outlined, '/mapa_global'),
                  const SizedBox(height: 15),
                  _buildWideActionCard("Levantamientos Gis", "Fotos y evidencias técnicas", Icons.language_rounded, '/mapa_fiscalizacion'),
                  const SizedBox(height: 15),
                  _buildWideActionCard(
                      "Estado de Obras",
                      "Saldos, multas y alertas contractuales",
                      Icons.assignment_late_outlined,
                      '/resumen_proyectos' // Ruta registrada en tu main.dart
                  ),
                  const SizedBox(height: 15),
                  _buildWideActionCard(
                      "Historial Proyectos",
                      "Auditoría de suspensiones, ampliaciones y multas",
                      Icons.gavel_rounded,
                      '/reporte_legal'
                  ),

                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- HEADER CON GRADIENTE Y AVATAR (FIJO) ---
  // --- HEADER CON PERFIL DE USUARIO DINÁMICO Y LOGO/FOTO (FIJO) ---
  Widget _buildHeader() {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [azulMuestraInicio, azulMuestraFin],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(50), bottomRight: Radius.circular(50)),
        boxShadow: [BoxShadow(color: azulInicio.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Row(
            children: [
              // ===============================================================
              // AQUÍ ESTÁ INYECTADA LA FOTO DEL PERFIL DEL FISCALIZADOR
              // ===============================================================
              _buildPerfilUsuarioAvatar(),
              // ===============================================================
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        _nombreUsuario, // Muestra el nombre real traído de Odoo
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                    ),
                    const SizedBox(height: 2),
                    Text(
                        "Geoproy v2 | 2026",
                        style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)
                    ),
                  ],
                ),
              ),
              if (_isSyncing) const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            ],
          ),
        ),
      ),
    );
  }

  /*
  Widget _buildHeader() {


    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        //gradient: LinearGradient(colors: [azulInicio, cianFin], begin: Alignment.topLeft, end: Alignment.bottomRight),

        gradient: LinearGradient(
          colors: [azulMuestraInicio, azulMuestraFin],
          begin: Alignment.topCenter,    // Gradiente vertical como en la muestra
          end: Alignment.bottomCenter,
        ),

        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(50), bottomRight: Radius.circular(50)),
        boxShadow: [BoxShadow(color: azulInicio.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: SafeArea(
        bottom: false, // Evita espacio extra en la parte inferior del Header
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Row(
            children: [
              //_buildNeonAvatar(),
              _buildPerfilUsuarioAvatar(),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Geoproy v3", style: GoogleFonts.poppins(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                    Text("Seguimiento de Obras", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                  ],
                ),
              ),
              if (_isSyncing) const SizedBox(width: 25, height: 25, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            ],
          ),
        ),
      ),
    );
  }
  */


  Widget _buildPerfilUsuarioAvatar() {
    ImageProvider? imagenPerfil;

    // Si Odoo nos devuelve la cadena binaria de la imagen, la decodificamos en memoria al vuelo
    if (_fotoBase64.isNotEmpty && _fotoBase64 != "false") {
      try {
        imagenPerfil = MemoryImage(base64Decode(_fotoBase64));
      } catch (e) {
        debugPrint("Error de decodificación Base64 en avatar: $e");
      }
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.6), width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)]
      ),
      child: CircleAvatar(
        radius: 34,
        backgroundColor: Colors.white24,
        backgroundImage: imagenPerfil,
        child: imagenPerfil == null
            ? Text(
          _nombreUsuario.isNotEmpty ? _nombreUsuario.substring(0, 1).toUpperCase() : "F",
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
        )
            : null,
      ),
    );
  }


  Widget _buildNeonAvatar() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white54, width: 2)),
      child: const CircleAvatar(
        radius: 32,
        backgroundColor: Colors.white24,
        child: Icon(Icons.manage_accounts_outlined, color: Colors.white, size: 35),
      ),
    );
  }

  // --- MÉTRICAS COMPACTAS EN FILA ---
  Widget _buildCompactMetrics() {
    return Row(
      children: [
        _miniMetricCard("Avance Global", "${(_ejecucionGlobal * 100).toInt()}%", azulInicio),
        const SizedBox(width: 12),
        _miniMetricCard("Alertas Críticas", _alertasCriticas.toString(), Colors.redAccent),
      ],
    );
  }

  Widget _miniMetricCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 10)],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // --- CUADRÍCULA 2X2 DE BOTONES ---
  Widget _buildMainMenuGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      children: [
        _gridItem("Portafolio\nde Obras", Icons.inventory_2_outlined, '/listado'),
        _gridItem("Nueva Obra", Icons.assignment_turned_in_outlined, '/form_proyecto'),
        _gridItem("Sincronizar", Icons.sync_rounded, null, action: _sincronizarConOdoo),
        _gridItem("Estadisticas", Icons.bar_chart_rounded, '/dashboard'),
      ],
    );
  }

  Widget _gridItem(String title, IconData icon, String? route, {Function? action}) {
    return InkWell(
      onTap: () => route != null ? Navigator.pushNamed(context, route).then((_) => _cargarResumenEjecutivo()) : action?.call(),
      child: Container(
        decoration: BoxDecoration(
          //gradient: LinearGradient(colors: [azulInicio, cianFin], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          gradient: LinearGradient(colors: [azulMuestraInicio, azulMuestraFin], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: azulInicio.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 45),
            const SizedBox(height: 10),
            Text(title, textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // --- BOTONES ANCHOS ---
  Widget _buildWideActionCard(String title, String sub, IconData icon, String route) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, route),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [azulInicio, cianFin]),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(15)),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text(sub, style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 16),
          ],
        ),
      ),
    );
  }

  // --- MENÚ INFERIOR ESTÁTICO ---
  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
      child: BottomNavigationBar(
        elevation: 0,
        backgroundColor: grisMenu,
        currentIndex: _currentIndex,
        onTap: (i) => i == 2 ? _showExitDialog() : setState(() => _currentIndex = i),
        selectedItemColor: azulFondo,
        unselectedItemColor: Colors.blueGrey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'Panel'),
          BottomNavigationBarItem(icon: Icon(Icons.info_outline_rounded), label: 'Acerca de'),
          BottomNavigationBarItem(icon: Icon(Icons.power_settings_new_rounded), label: 'Salir'),
        ],
      ),
    );
  }

  // --- PÁGINA DE CRÉDITOS CON LOGO ---
  Widget _buildCreditsPage() {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          width: double.infinity, // Asegura que el contenido use todo el ancho para el centrado
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center, // Centrado horizontal
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: azulInicio.withOpacity(0.2), width: 4)
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: Image.asset(
                    'assets/images/logoprincipok.png',
                    height: 140,
                    width: 130,
                    fit: BoxFit.contain,
                    errorBuilder: (c, e, s) => Icon(Icons.business_rounded, size: 80, color: azulFondo),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Text(
                  "GEOPROY",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w900, color: azulFondo)
              ),
              const Text(
                  "Sistema de Seguimiento de Obras Publicas Verificables",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.blueGrey, fontSize: 13)
              ),
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20, horizontal: 40),
                  child: Divider()
              ),
              /*
              Text(
                  "DESARROLLADO POR:",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 2)
              ),
              */
              const SizedBox(height: 5),
              Text(
                  //"Ing. Fausto Lucano\nCartotips",
                  "GAD Municipal de Otavalo",
                  textAlign: TextAlign.center, // Centra las dos líneas de nombre y empresa
                  style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.bold, color: azulFondo)
              ),
              /*const SizedBox(height: 35),
              _contactRow(Icons.alternate_email_rounded, "cartotips@gmail.com"),
              const SizedBox(height: 12),
              _contactRow(Icons.phone_android_rounded, "+593 982644719"),
              const SizedBox(height: 50),*/
              const Text(
                  "Otavalo - Ecuador",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contactRow(IconData i, String t) => Row(
    mainAxisAlignment: MainAxisAlignment.center, // Centra horizontalmente la fila de contacto
    children: [
      Icon(i, size: 18, color: azulInicio),
      const SizedBox(width: 10),
      Text(
          t,
          style: TextStyle(fontWeight: FontWeight.w600, color: azulFondo, fontSize: 14)
      ),
    ],
  );


  Widget _buildSectionLabel(String title) {
    return Text(title, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.blueGrey, letterSpacing: 1.5));
  }


  // --- RECONSTRUCCIÓN DEL DIÁLOGO DE SALIDA CON DESTRUCCIÓN DE SESIÓN ---
  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFF1A237E)),
            SizedBox(width: 10),
            Text("Cerrar Sesión"),
          ],
        ),
        content: const Text("¿Está seguro que desea salir del sistema Geoproy y regresar al control de acceso?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("NO", style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
            onPressed: () async {
              Navigator.pop(ctx); // Cierra el modal de confirmación

              // 1. LIMPIEZA DE ESTRUCTURA LOCAL DE SESIÓN (Olvida al usuario)
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear(); // Borra 'isLoggedIn' y 'userData' por completo

              if (!mounted) return;

              // 2. REDIRECCIÓN LIMPIA HACIA EL LOGIN DESTRUYENDO LA PILA
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login', // Invoca la ruta del login que registramos en tu main.dart
                    (route) => false, // Elimina todas las pantallas previas de la RAM
              );
            },
            child: const Text("SÍ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

/*
  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Cerrar Sesión"),
        content: const Text("¿Desea salir de la aplicación Geoproy?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("NO")),
          ElevatedButton(onPressed: () => SystemNavigator.pop(), style: ElevatedButton.styleFrom(backgroundColor: azulFondo), child: const Text("SÍ", style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }
  */


}
