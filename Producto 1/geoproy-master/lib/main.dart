import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Módulo de persistencia

// Pantallas del ecosistema
import 'screens/home_screen.dart';
import 'screens/formularios/form.dart';
import 'screens/formularios/gestion_tiempos_screen.dart';
import 'screens/map_screen.dart';
import 'screens/submenus/dashboard.dart';
import 'screens/listados/list.dart';
import 'screens/mapas/mapa_proys_screen.dart';
import 'screens/mapas/mapa_hitos_screen.dart';
import 'screens/auth/login_screen.dart'; // Importación de tu LoginScreen
import 'data/api_webservice.dart';
import 'screens/listados/list_resumen_proys.dart';
import 'screens/listados/list_historial_legal.dart';


// Esta clase permite saltar la verificación de certificados SSL
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}


void main() async {
  // 1. Garantiza la inicialización correcta de bindings nativos antes del login
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();

  // 2. VERIFICACIÓN AUTOMÁTICA DE SESIÓN PERSISTENTE
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  // Pasamos el flag al widget raíz
  runApp(ConstructProApp(isLoggedIn: isLoggedIn));
}

class ConstructProApp extends StatelessWidget {
  final bool isLoggedIn;
  const ConstructProApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoProy v1',
      debugShowCheckedModeBanner: false,

      // 1. LOCALIZACIÓN (Español para calendarios de suspensiones y ampliaciones)
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es', 'ES')],

      // 2. TEMA VISUAL (Ingeniería Moderna)
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E293B),
          primary: const Color(0xFF1E293B),
          surface: const Color(0xFFF8FAFC),
        ),
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
        appBarTheme: AppBarTheme(
          centerTitle: true,
          backgroundColor: const Color(0xFF1E293B),
          foregroundColor: Colors.white,
          titleTextStyle: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      // 3. ENRUTAMIENTO DINÁMICO INTELIGENTE
      // Si el flag de sesión es true arranca en el Home, si no, exige autenticación en el Login
      initialRoute: isLoggedIn ? '/' : '/login',

      onGenerateRoute: (settings) {
        final args = settings.arguments;

        switch (settings.name) {
        // Nueva ruta añadida para el control de acceso inicial
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginScreen());

          case '/':
            return MaterialPageRoute(builder: (_) => const HomeScreen());

          case '/listado':
            return MaterialPageRoute(builder: (_) => const ProjectListScreen());

          case '/dashboard':
            return MaterialPageRoute(builder: (_) => const DashboardScreen());

          case '/form_proyecto':
            return MaterialPageRoute(builder: (_) => FormularioObra(arguments: args));

          case '/form_hito':
            return MaterialPageRoute(builder: (_) => FormularioObra(arguments: args));

          case '/mapa':
            return MaterialPageRoute(builder: (_) => MapHitoScreen(hitoId: args is int ? args : 1));

          case '/mapa_global':
            return MaterialPageRoute(builder: (_) => const MapaProyectosScreen());

          case '/mapa_fiscalizacion':
            return MaterialPageRoute(builder: (_) => const MapaFiscalizacionScreen());

          case '/gestion_tiempos':
            return MaterialPageRoute(
              builder: (context) => GestionTiemposScreen(arguments: settings.arguments),
            );

          case '/resumen_proyectos':
            return MaterialPageRoute(builder: (_) => const ResumenProyectosScreen());

          case '/reporte_legal':
            return MaterialPageRoute(builder: (_) => const ReporteHistorialLegalScreen());

          default:
          // En caso de ruta rota o descolgada, redirige de forma segura según el estado de sesión
            return MaterialPageRoute(builder: (_) => isLoggedIn ? const HomeScreen() : const LoginScreen());
        }
      },
    );
  }
}
