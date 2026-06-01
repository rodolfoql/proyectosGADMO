import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'register_screen.dart';
import '../home_screen.dart';
import '../../data/config_webservice.dart';

// Bypass para certificados HTTPS no válidos (Desarrollo)
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _isLoading = false;

  /// REFRESCAR SESIÓN: Limpia datos viejos y normaliza los nuevos.
  /// Esto evita la pantalla en blanco con usuarios antiguos.
  Future<void> _refreshAndSaveSession(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();

    // Limpiamos rastro de sesiones antiguas
    await prefs.clear();

    // NORMALIZACIÓN: Odoo devuelve 'false' (bool) en campos vacíos.
    // Convertimos todo a String para que el HomeScreen no falle.
    Map<String, dynamic> cleanData = {
      "id": userData['id'] ?? 0,
      "name": (userData['name'] != null && userData['name'] != false)
          ? userData['name'].toString()
          : "Usuario",
      "f_ciuemail": (userData['f_ciuemail'] != null && userData['f_ciuemail'] != false)
          ? userData['f_ciuemail'].toString() : "",
      "f_ciucelu": (userData['f_ciucelu'] != null && userData['f_ciucelu'] != false)
          ? userData['f_ciucelu'].toString() : "",
      "f_ciuimag": (userData['f_ciuimag'] != null && userData['f_ciuimag'] != false)
          ? userData['f_ciuimag'].toString() : "",
      "f_ciulogin": (userData['f_ciulogin'] != null && userData['f_ciulogin'] != false)
          ? userData['f_ciulogin'].toString() : "Invitado",
    };

    // Guardamos los datos limpios
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userData', jsonEncode(cleanData));
  }

  // Petición al WebService de Odoo
  Future<void> _login() async {
    if (_userController.text.isEmpty || _passController.text.isEmpty) {
      _showSnackBar("Por favor complete los campos");
      return;
    }

    setState(() => _isLoading = true);

    //const String url = 'https://geoportal.otavalo.gob.ec/api/login_ciudadano';
    const String url = '${AppConfig.baseUrl}/api/login_ciudadano';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "params": {
            "f_ciulogin": _userController.text,
            "f_ciuclave": _passController.text,
          }
        }),
      ).timeout(const Duration(seconds: 12)); // Timeout de seguridad

      final decodedResponse = jsonDecode(response.body);
      final result = decodedResponse['result'];

      if (result != null && result['status'] == true) {
        // Refrescamos y normalizamos la sesión
        await _refreshAndSaveSession(result['data']);

        if (!mounted) return;

        _showSnackBar("¡Bienvenido ${result['data']['name'] ?? ''}!");

        // Navegación limpia eliminando el historial (evita pantalla blanca al volver)
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
        );
      } else {
        _showSnackBar(result?['message'] ?? "Error de autenticación");
      }
    } catch (e) {
      _showSnackBar("Error de conexión: Verifique su internet");
      debugPrint("Error Login: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    final Color azulMuestraInicio = const Color(0xFF1A237E); // Azul Marino Profundo
    final Color azulMuestraFin = const Color(0xFF0D47A1);

    return Scaffold(
      //backgroundColor: Colors.black,
      backgroundColor: azulMuestraInicio,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            //colors: [Colors.black, Colors.grey.shade900, Colors.black],
            colors: [azulMuestraInicio, azulMuestraFin, azulMuestraInicio],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 80),
          child: Column(
            children: [
              // Logotipo responsivo
              Container(
                width: screenWidth * 0.8,
                height: 250,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/bienvlogin.png'),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Bienvenido\nGestión de Obras",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w300),
              ),
              const SizedBox(height: 50),

              // Inputs
              _buildInput(_userController, "Usuario", Icons.person_outline),
              const SizedBox(height: 20),
              _buildInput(_passController, "Contraseña", Icons.lock_outline, isPass: true),

              const SizedBox(height: 40),

              // Botón Entrar
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent.shade400,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 10,
                    shadowColor: Colors.blueAccent.withOpacity(0.4),
                  ),
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text("INICIAR SESIÓN", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),

              const SizedBox(height: 30),

              // Botón Ir a Registro
              TextButton(
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RegisterScreen())
                  );
                },
                child: RichText(
                  text: TextSpan(
                    text: "¿No tienes cuenta? ",
                    style: const TextStyle(color: Colors.white70),
                    children: [
                      TextSpan(
                        text: "Regístrate ahora",
                        style: TextStyle(color: Colors.blueAccent.shade200, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController ctrl, String label, IconData icon, {bool isPass = false}) {
    return TextField(
      controller: ctrl,
      obscureText: isPass,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.blueAccent.shade200),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.blueAccent.shade200),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
      ),
    );
  }
}
