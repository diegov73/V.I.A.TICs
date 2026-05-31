import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';

const String baseUrl = 'http://192.168.18.175:8000';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VIA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF534AB7)),
      ),
      home: const VIALoginScreen(),
    );
  }
}

// ─── HELPER TalkBack ──────────────────────────────────────────────────────────

Future<void> _hablar(FlutterTts tts, String texto) async {
  final talkback =
      WidgetsBinding.instance.accessibilityFeatures.accessibleNavigation;
  if (!talkback) {
    await tts.speak(texto);
  }
}

// ─── LOGIN ───────────────────────────────────────────────────────────────────

class VIALoginScreen extends StatefulWidget {
  const VIALoginScreen({super.key});

  @override
  State<VIALoginScreen> createState() => _VIALoginScreenState();
}

class _VIALoginScreenState extends State<VIALoginScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _blinkController;
  final FlutterTts tts = FlutterTts();

  final correoCtrl = TextEditingController();
  final contraCtrl = TextEditingController();
  String mensaje = '';
  bool cargando = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _configurarTTS();
    Future.delayed(const Duration(milliseconds: 800), () {
      _hablar(tts,
          'Bienvenido a VIA. '
          'Desliza a la derecha para moverte entre los elementos. '
          'Doble toque para activar.');
    });
  }

  Future<void> _configurarTTS() async {
    await tts.setLanguage('es');
    await tts.setSpeechRate(0.45);
    await tts.setVolume(1.0);
  }

  @override
  void dispose() {
    tts.stop();
    _pulseController.dispose();
    _blinkController.dispose();
    correoCtrl.dispose();
    contraCtrl.dispose();
    super.dispose();
  }

  Future<void> login() async {
    setState(() {
      cargando = true;
      mensaje = '';
    });
    await tts.speak('Iniciando sesión, por favor espera.');
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'correo': correoCtrl.text.trim(),
          'contrasena': contraCtrl.text,
        }),
      );
      final data = jsonDecode(res.body);
      if (data['estado'] == 'exito') {
        final nombre = data['usuario']['nombre'] ?? 'Usuario';
        final idUsuario = data['usuario']['id'] ?? '';
        await tts.speak('Bienvenido $nombre');
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  VIAHomeScreen(nombre: nombre, idUsuario: idUsuario),
            ),
          );
        }
      } else {
        final msg = data['mensaje'] ?? 'Error al iniciar sesión';
        setState(() => mensaje = msg);
        await tts.speak(msg);
      }
    } catch (e) {
      const msg = 'No se pudo conectar al servidor. Verifica tu conexión.';
      setState(() => mensaje = msg);
      await tts.speak(msg);
    } finally {
      setState(() => cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F4FF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Semantics(
            explicitChildNodes: true,
            child: Column(
              children: [
                ExcludeSemantics(child: _buildEyeLogo()),
                const SizedBox(height: 20),
                Semantics(
                  label: 'VIA, Visión Inteligente Asistida',
                  child: ExcludeSemantics(
                    child: Column(
                      children: const [
                        Text('V.I.A',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF26215C))),
                        SizedBox(height: 4),
                        Text('VISIÓN INTELIGENTE ASISTIDA',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF534AB7),
                                letterSpacing: 2)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ExcludeSemantics(child: _buildSoundWave()),
                const SizedBox(height: 28),
                Semantics(
                  label: 'Campo correo electrónico',
                  hint: 'Doble toque para escribir tu correo',
                  textField: true,
                  child: TextField(
                    controller: correoCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(fontSize: 18),
                    decoration: _inputDeco('Correo electrónico'),
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  label: 'Campo contraseña',
                  hint: 'Doble toque para escribir tu contraseña',
                  textField: true,
                  obscured: true,
                  child: TextField(
                    controller: contraCtrl,
                    obscureText: true,
                    style: const TextStyle(fontSize: 18),
                    decoration: _inputDeco('Contraseña'),
                  ),
                ),
                const SizedBox(height: 8),
                if (mensaje.isNotEmpty)
                  Semantics(
                    label: mensaje,
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(mensaje,
                          style: const TextStyle(
                              color: Color(0xFFA32D2D), fontSize: 13)),
                    ),
                  ),
                const SizedBox(height: 12),
                Semantics(
                  label: 'Iniciar sesión',
                  hint: 'Doble toque para entrar',
                  button: true,
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: cargando ? null : login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3C3489),
                        foregroundColor: const Color(0xFFEEEDFE),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: cargando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Iniciar sesión',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Semantics(
                  label: 'Crear cuenta nueva',
                  hint: 'Doble toque para registrarte',
                  button: true,
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const VIARegistroScreen()),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF534AB7),
                        side: const BorderSide(
                            color: Color(0xFFAFA9EC), width: 0.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('¿Sin cuenta? Regístrate',
                          style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Semantics(
                  label: 'Iniciar sesión con Google, próximamente disponible',
                  button: true,
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.g_mobiledata_rounded, size: 24),
                      label: const Text('Google, próximamente',
                          style: TextStyle(fontSize: 14)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF888780),
                        side: const BorderSide(
                            color: Color(0xFFD3D1C7), width: 0.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ExcludeSemantics(child: _buildDots()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEyeLogo() {
    return Center(
      child: SizedBox(
        width: 110,
        height: 110,
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulseController, _blinkController]),
          builder: (context, child) {
            final blink = _blinkController.value;
            final isBlinking = blink > 0.9;
            final scaleY = isBlinking
                ? (1 - ((blink - 0.9) / 0.05)).clamp(0.05, 1.0)
                : 1.0;
            return CustomPaint(
              painter: EyePainter(
                pulseValue: _pulseController.value,
                scaleY: scaleY,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSoundWave() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _BarraOndas(height: 14),
        _BarraOndas(height: 20),
        _BarraOndas(height: 26),
        _BarraOndas(height: 20),
        _BarraOndas(height: 16),
        _BarraOndas(height: 22),
        _BarraOndas(height: 14),
      ],
    );
  }

  Widget _buildDots() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(radius: 3.5, backgroundColor: Color(0xFF7F77DD)),
          SizedBox(width: 16),
          CircleAvatar(radius: 3.5, backgroundColor: Color(0xFFAFA9EC)),
          SizedBox(width: 16),
          CircleAvatar(radius: 3.5, backgroundColor: Color(0xFF534AB7)),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFAFA9EC), width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFAFA9EC), width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF7F77DD), width: 1.5),
        ),
      );
}

// ─── REGISTRO ────────────────────────────────────────────────────────────────

class VIARegistroScreen extends StatefulWidget {
  const VIARegistroScreen({super.key});

  @override
  State<VIARegistroScreen> createState() => _VIARegistroScreenState();
}

class _VIARegistroScreenState extends State<VIARegistroScreen> {
  final FlutterTts tts = FlutterTts();
  final nombreCtrl = TextEditingController();
  final correoCtrl = TextEditingController();
  final contraCtrl = TextEditingController();
  String mensaje = '';
  bool cargando = false;

  @override
  void initState() {
    super.initState();
    tts.setLanguage('es');
    tts.setSpeechRate(0.45);
    Future.delayed(const Duration(milliseconds: 800), () {
      _hablar(tts,
          'Pantalla de registro. '
          'Tres campos: nombre, correo y contraseña. '
          'Desliza a la derecha para navegar.');
    });
  }

  @override
  void dispose() {
    tts.stop();
    nombreCtrl.dispose();
    correoCtrl.dispose();
    contraCtrl.dispose();
    super.dispose();
  }

  Future<void> registro() async {
    setState(() {
      cargando = true;
      mensaje = '';
    });
    await tts.speak('Creando cuenta, por favor espera.');
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/registro'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nombre': nombreCtrl.text.trim(),
          'correo': correoCtrl.text.trim(),
          'contrasena': contraCtrl.text,
        }),
      );
      final data = jsonDecode(res.body);
      if (data['estado'] == 'exito') {
        await tts.speak('Cuenta creada. Volviendo al inicio de sesión.');
        if (mounted) Navigator.pop(context);
      } else {
        final msg = data['mensaje'] ?? 'Error al registrarse';
        setState(() => mensaje = msg);
        await tts.speak(msg);
      }
    } catch (e) {
      const msg = 'No se pudo conectar al servidor.';
      setState(() => mensaje = msg);
      await tts.speak(msg);
    } finally {
      setState(() => cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F4FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F4FF),
        elevation: 0,
        leading: Semantics(
          label: 'Volver',
          hint: 'Doble toque para volver al inicio de sesión',
          button: true,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                color: Color(0xFF534AB7), size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: ExcludeSemantics(
          child: const Text('Registro',
              style: TextStyle(
                  color: Color(0xFF26215C), fontWeight: FontWeight.w500)),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Semantics(
            explicitChildNodes: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  label: 'Campo nombre',
                  hint: 'Doble toque para escribir tu nombre',
                  textField: true,
                  child: TextField(
                    controller: nombreCtrl,
                    style: const TextStyle(fontSize: 18),
                    decoration: _inputDeco('Nombre'),
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  label: 'Campo correo electrónico',
                  hint: 'Doble toque para escribir tu correo',
                  textField: true,
                  child: TextField(
                    controller: correoCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(fontSize: 18),
                    decoration: _inputDeco('Correo electrónico'),
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  label: 'Campo contraseña',
                  hint: 'Doble toque para escribir tu contraseña',
                  textField: true,
                  obscured: true,
                  child: TextField(
                    controller: contraCtrl,
                    obscureText: true,
                    style: const TextStyle(fontSize: 18),
                    decoration: _inputDeco('Contraseña'),
                  ),
                ),
                const SizedBox(height: 8),
                if (mensaje.isNotEmpty)
                  Semantics(
                    label: mensaje,
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(mensaje,
                          style: const TextStyle(
                              color: Color(0xFFA32D2D), fontSize: 13)),
                    ),
                  ),
                const SizedBox(height: 16),
                Semantics(
                  label: 'Crear cuenta',
                  hint: 'Doble toque para crear tu cuenta',
                  button: true,
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: cargando ? null : registro,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3C3489),
                        foregroundColor: const Color(0xFFEEEDFE),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: cargando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Crear cuenta',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFAFA9EC), width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFAFA9EC), width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF7F77DD), width: 1.5),
        ),
      );
}

// ─── HOME ─────────────────────────────────────────────────────────────────────

class VIAHomeScreen extends StatefulWidget {
  final String nombre;
  final String idUsuario;
  const VIAHomeScreen(
      {super.key, required this.nombre, required this.idUsuario});

  @override
  State<VIAHomeScreen> createState() => _VIAHomeScreenState();
}

class _VIAHomeScreenState extends State<VIAHomeScreen> {
  final FlutterTts tts = FlutterTts();
  bool reproduciendo = false;
  int? indiceReproduciendo;

  Map<String, dynamic> estadoActual = {
    'descripcion': 'Esperando descripción...',
    'timestamp': 0,
  };

  String estadoESP32 = 'Sin conexión';
  String bateria = '--%';
  List<String> historial = [];
  bool cargandoHistorial = false;

  @override
  void initState() {
    super.initState();
    _configurarTTS();
    _cargarUltimaDescripcion();
    _cargarHistorial();
    Future.delayed(const Duration(milliseconds: 800), () {
      _hablar(tts,
          'Bienvenido ${widget.nombre}. '
          'Desliza a la derecha para navegar por la pantalla principal.');
    });
  }

  Future<void> _configurarTTS() async {
    await tts.setLanguage('es');
    await tts.setSpeechRate(0.45);
    await tts.setVolume(1.0);
    tts.setCompletionHandler(() {
      setState(() {
        reproduciendo = false;
        indiceReproduciendo = null;
      });
    });
  }

  Future<void> _cargarUltimaDescripcion() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/latest-info'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() => estadoActual = data);
      }
    } catch (_) {}
  }

  Future<void> _cargarHistorial() async {
    setState(() => cargandoHistorial = true);
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/historial/${widget.idUsuario}'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          historial = data
              .take(10)
              .map((e) => e['texto']?.toString() ?? '')
              .where((t) => t.isNotEmpty)
              .toList();
        });
      }
    } catch (_) {}
    setState(() => cargandoHistorial = false);
  }

  Future<void> _reproducir(String texto, {int? indice}) async {
    if (reproduciendo) {
      await tts.stop();
      setState(() {
        reproduciendo = false;
        indiceReproduciendo = null;
      });
      if (indiceReproduciendo == indice) return;
    }
    setState(() {
      reproduciendo = true;
      indiceReproduciendo = indice;
    });
    await tts.speak(texto);
  }

  Future<void> _pausar() async {
    await tts.stop();
    setState(() {
      reproduciendo = false;
      indiceReproduciendo = null;
    });
  }

  void cerrarSesion() async {
    await tts.speak('Cerrando sesión.');
    await tts.stop();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const VIALoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final descripcion =
        estadoActual['descripcion'] ?? 'Esperando descripción...';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F4FF),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _hablar(tts, 'Actualizando.');
            await _cargarUltimaDescripcion();
            await _cargarHistorial();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Semantics(
              explicitChildNodes: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── HEADER ──
                  ExcludeSemantics(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Bienvenido,',
                                style: TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF888780))),
                            Text(widget.nombre,
                                style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF26215C))),
                          ],
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── ESTADO DISPOSITIVO ──
                  Semantics(
                    label:
                        'Estado del dispositivo. ESP32: $estadoESP32. Batería: $bateria',
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFAFA9EC), width: 0.5),
                      ),
                      child: ExcludeSemantics(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Estado del dispositivo',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF534AB7),
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.devices_rounded,
                                    color: Color(0xFF888780), size: 20),
                                const SizedBox(width: 8),
                                const Text('ESP32',
                                    style: TextStyle(fontSize: 15)),
                                const Spacer(),
                                Text(estadoESP32,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF888780))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.battery_unknown_rounded,
                                    color: Color(0xFF888780), size: 20),
                                const SizedBox(width: 8),
                                const Text('Batería',
                                    style: TextStyle(fontSize: 15)),
                                const Spacer(),
                                Text(bateria,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF888780))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── ÚLTIMA DESCRIPCIÓN ──
                  Semantics(
                    label: 'Última descripción del entorno: $descripcion',
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFAFA9EC), width: 0.5),
                      ),
                      child: ExcludeSemantics(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Última descripción',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF534AB7),
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            Text(descripcion,
                                style: const TextStyle(
                                    fontSize: 17,
                                    color: Color(0xFF26215C),
                                    height: 1.6)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Botón reproducir
                  Semantics(
                    label: reproduciendo && indiceReproduciendo == null
                        ? 'Pausar descripción'
                        : 'Reproducir descripción',
                    hint: 'Doble toque para reproducir o pausar',
                    button: true,
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed:
                            reproduciendo && indiceReproduciendo == null
                                ? _pausar
                                : () => _reproducir(descripcion),
                        icon: Icon(
                          reproduciendo && indiceReproduciendo == null
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 28,
                        ),
                        label: Text(
                          reproduciendo && indiceReproduciendo == null
                              ? 'Pausar'
                              : 'Reproducir descripción',
                          style: const TextStyle(fontSize: 18),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3C3489),
                          foregroundColor: const Color(0xFFEEEDFE),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── HISTORIAL ──
                  ExcludeSemantics(
                    child: const Text('Últimas 10 descripciones',
                        style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF534AB7),
                            fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(height: 10),

                  if (cargandoHistorial)
                    const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF534AB7)),
                    )
                  else if (historial.isEmpty)
                    Semantics(
                      label: 'Sin descripciones guardadas aún',
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          'Aún no hay descripciones guardadas.',
                          style: TextStyle(
                              fontSize: 16, color: Color(0xFF888780)),
                        ),
                      ),
                    )
                  else
                    ...historial.asMap().entries.map((entry) {
                      final i = entry.key;
                      final texto = entry.value;
                      final esteReproduciendo =
                          reproduciendo && indiceReproduciendo == i;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Semantics(
                                label: 'Descripción ${i + 1}: $texto',
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: esteReproduciendo
                                          ? const Color(0xFF7F77DD)
                                          : const Color(0xFFAFA9EC),
                                      width: esteReproduciendo ? 1.5 : 0.5,
                                    ),
                                  ),
                                  child: ExcludeSemantics(
                                    child: Text(texto,
                                        style: const TextStyle(
                                            fontSize: 15,
                                            color: Color(0xFF26215C),
                                            height: 1.5),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Semantics(
                              label: esteReproduciendo
                                  ? 'Pausar descripción ${i + 1}'
                                  : 'Reproducir descripción ${i + 1}',
                              hint: 'Doble toque para reproducir o pausar',
                              button: true,
                              child: IconButton(
                                onPressed: esteReproduciendo
                                    ? _pausar
                                    : () => _reproducir(texto, indice: i),
                                icon: Icon(
                                  esteReproduciendo
                                      ? Icons.pause_circle_rounded
                                      : Icons.play_circle_rounded,
                                  color: const Color(0xFF534AB7),
                                  size: 36,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 32),

                  // ── CERRAR SESIÓN ──
                  Semantics(
                    label: 'Cerrar sesión',
                    hint: 'Doble toque para cerrar sesión',
                    button: true,
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: cerrarSesion,
                        icon: const Icon(Icons.logout_rounded,
                            color: Color(0xFF534AB7)),
                        label: const Text('Cerrar sesión',
                            style: TextStyle(
                                fontSize: 16, color: Color(0xFF534AB7))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Color(0xFFAFA9EC), width: 0.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── WIDGETS AUXILIARES ───────────────────────────────────────────────────────

class _BarraOndas extends StatelessWidget {
  final double height;
  const _BarraOndas({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF7F77DD),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// ─── PAINTERS ────────────────────────────────────────────────────────────────

class EyePainter extends CustomPainter {
  final double pulseValue;
  final double scaleY;

  EyePainter({required this.pulseValue, required this.scaleY});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (int i = 0; i < 3; i++) {
      final progress = (pulseValue + i * 0.4) % 1.0;
      final radius = 30.0 + progress * 25;
      final opacity = (1 - progress) * 0.6;
      canvas.drawCircle(center, radius,
          Paint()
            ..color = const Color(0xFF7F77DD).withOpacity(opacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }
    canvas.drawCircle(
        center, 36, Paint()..color = const Color(0xFFEEEDFE));
    canvas.drawCircle(center, 36,
        Paint()
          ..color = const Color(0xFFAFA9EC)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1.0, scaleY);
    canvas.translate(-center.dx, -center.dy);
    final eyePath = Path()
      ..moveTo(center.dx - 22, center.dy)
      ..quadraticBezierTo(
          center.dx, center.dy - 16, center.dx + 22, center.dy)
      ..quadraticBezierTo(
          center.dx, center.dy + 16, center.dx - 22, center.dy);
    canvas.drawPath(eyePath, Paint()..color = Colors.white);
    canvas.drawCircle(
        center, 18, Paint()..color = const Color(0xFF534AB7));
    canvas.drawCircle(
        center, 10, Paint()..color = const Color(0xFF26215C));
    canvas.drawCircle(Offset(center.dx + 5, center.dy - 5), 3.5,
        Paint()..color = Colors.white.withOpacity(0.7));
    canvas.restore();
    final rayPaint = Paint()
      ..color = const Color(0xFFAFA9EC)
      ..strokeWidth = 0.5;
    canvas.drawLine(Offset(center.dx - 36, center.dy),
        Offset(center.dx - 51, center.dy - 7), rayPaint);
    canvas.drawLine(Offset(center.dx - 36, center.dy),
        Offset(center.dx - 53, center.dy), rayPaint);
    canvas.drawLine(Offset(center.dx - 36, center.dy),
        Offset(center.dx - 51, center.dy + 7), rayPaint);
    canvas.drawLine(Offset(center.dx + 36, center.dy),
        Offset(center.dx + 51, center.dy - 7), rayPaint);
    canvas.drawLine(Offset(center.dx + 36, center.dy),
        Offset(center.dx + 53, center.dy), rayPaint);
    canvas.drawLine(Offset(center.dx + 36, center.dy),
        Offset(center.dx + 51, center.dy + 7), rayPaint);
  }

  @override
  bool shouldRepaint(EyePainter old) => true;
}