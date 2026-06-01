import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'login_screen.dart';
import '../../data/config_webservice.dart';


class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _celuCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  File? _imageFile;
  String _base64Image = "";
  bool _isLoading = false;

  // Obtener ubicación con manejo de errores corregido
  Future<Map<String, dynamic>> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return {"latitude": 0.2268062, "longitude": -78.2629038};
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return {"latitude": 0.2268062, "longitude": -78.2629038};
      }
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      return {"latitude": position.latitude, "longitude": position.longitude};
    } catch (e) {
      return {"latitude": 0.2268062, "longitude": -78.2629038};
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 50);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _base64Image = base64Encode(_imageFile!.readAsBytesSync());
      });
    }
  }

  Future<void> _register() async {
    if (_userCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      _showMsg("Usuario y clave son obligatorios");
      return;
    }

    setState() => _isLoading = true;
    final coords = await _getCurrentLocation();

    // REEMPLAZAR CON TU URL
    //const String url = 'https://geoportal.otavalo.gob.ec/api/registrar_ciudadano';
    const String url = '${AppConfig.baseUrl}/api/registrar_ciudadano';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "params": {
            "name": _nameCtrl.text,
            "f_ciuemail": _emailCtrl.text,
            "f_ciucelu": _celuCtrl.text,
            "f_ciuimag": _base64Image,
            "f_ciulogin": _userCtrl.text,
            "f_ciuclave": _passCtrl.text,
            "f_ciucoords": coords, // Enviado como Map para el campo Json de Odoo
          }
        }),
      );

      final result = jsonDecode(response.body);

      // Corrección de acceso a respuesta de Odoo
      if (result['result'] != null && result['result']['status'] == true) {
        _showMsg("¡Registro exitoso!");
        if (mounted) {
          //Navigator.pop(context);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }

      } else {
        //_showMsg(result['result']?['message'] ?? "Error desconocido");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      _showMsg("Error de conexión: $e");
    } finally {
      setState() => _isLoading = false;
    }
  }

  void _showMsg(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {

    final Color azulMuestraInicio = const Color(0xFF1A237E); // Azul Marino Profundo

    return Scaffold(
      //backgroundColor: Colors.black,
      backgroundColor: azulMuestraInicio,
      appBar: AppBar(
        title: const Text("Crear Cuenta", style: TextStyle(color: Colors.blueAccent)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey.shade900,
                backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                child: _imageFile == null
                    ? const Icon(Icons.add_a_photo, color: Colors.blueAccent, size: 40)
                    : null,
              ),
            ),
            const SizedBox(height: 30),
            _buildField(_nameCtrl, "Nombres Completos", Icons.person),
            const SizedBox(height: 15),
            _buildField(_emailCtrl, "Email", Icons.email),
            const SizedBox(height: 15),
            _buildField(_celuCtrl, "Celular", Icons.phone),
            const SizedBox(height: 15),
            _buildField(_userCtrl, "Usuario", Icons.account_circle),
            const SizedBox(height: 15),
            _buildField(_passCtrl, "Contraseña", Icons.lock, isObscure: true),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: _isLoading ? null : _register,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text("REGISTRARME", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, {bool isObscure = false}) {
    return TextField(
      controller: ctrl,
      obscureText: isObscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.white12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.blueAccent)),
      ),
    );
  }
}
