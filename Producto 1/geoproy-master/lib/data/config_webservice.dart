class AppConfig {
  // 1. URL BASE DEL SERVIDOR (Geoportal Otavalo)
  static const String baseUrl = "https://geoportal.otavalo.gob.ec";

  // 2. PARÁMETROS TÉCNICOS DE CONEXIÓN
  static const int timeoutSeconds = 40; // Tiempo de espera para servidores lentos

  // 3. ENDPOINTS PARA ATRACTIVOS (Requiere concatenar /id)
  // Ejemplo de uso: "${AppConfig.baseUrl}${AppConfig.endpointAtractivo}23"
  static const String endpointAtractivo = "/api/gatractivo/";

  // 4. ENDPOINTS PARA SERVICIOS TURÍSTICOS (Requiere concatenar /id)
  // Ejemplo de uso: "${AppConfig.baseUrl}${AppConfig.endpointServicios}27"
  static const String endpointServicios = "/api/gservturistic/";

  // 5. ENDPOINT PARA RUTAS TÉCNICAS (Trae todas sin ID)
  static const String endpointRutas = "/api/gadmorutas";

  // 6. ENDPOINT PARA ACTORES CULTURALES
  static const String endpointActores = "/api/gadmoact";

  // 7. ENDPOINT PARA REGISTRO DE DENUNCIAS (POST JSON-RPC)
  static const String endpointCrearDenuncia = "/api/crea_denciu";

  // 8. IDENTIDAD VISUAL (Rutas de assets comunes)
  static const String logoPrincipal = 'assets/images/logoprincipok.png';
}
