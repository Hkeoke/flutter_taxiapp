import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isLoading = false;

  // Define el color principal basado en el logo
  final Color primaryColor = Colors.red; // O el rojo específico de tu logo
  final Color backgroundColor = Colors.black;
  final Color textColor = Colors.white;
  final Color hintColor = Colors.grey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Remueve el AppBar o ajústalo al estilo oscuro si lo prefieres
      // appBar: AppBar(
      //   title: Text('Iniciar Sesión'),
      //   backgroundColor: backgroundColor,
      //   foregroundColor: textColor,
      // ),
      backgroundColor: backgroundColor, // Fondo oscuro
      body: SafeArea(
        // Usa SafeArea para evitar solapamientos con la UI del sistema
        child: Center(
          // Centra el contenido verticalmente
          child: SingleChildScrollView(
            // Permite scroll si el contenido no cabe
            padding: const EdgeInsets.all(24.0), // Aumenta el padding
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Reemplaza el Icon con la imagen del logo
                Image.asset(
                  'assets/images/logorikera.png', // Ruta a tu logo
                  height: 80, // Ajusta la altura según necesites
                  // Considera width si la imagen es muy ancha
                ),
                SizedBox(height: 40), // Más espacio después del logo
                TextField(
                  controller: _phoneController,
                  style: TextStyle(
                    color: textColor,
                  ), // Color del texto ingresado
                  decoration: InputDecoration(
                    labelText: 'Número de teléfono',
                    labelStyle: TextStyle(color: hintColor), // Color del label
                    enabledBorder: OutlineInputBorder(
                      // Borde cuando no está enfocado
                      borderSide: BorderSide(color: hintColor.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      // Borde cuando está enfocado
                      borderSide: BorderSide(color: primaryColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: Icon(Icons.phone, color: hintColor),
                    filled: true, // Relleno para el campo
                    fillColor: Colors.grey.shade900.withOpacity(
                      0.7,
                    ), // Color de relleno oscuro
                  ),
                  keyboardType: TextInputType.phone,
                ),
                SizedBox(height: 20), // Espacio ajustado
                TextField(
                  controller: _pinController,
                  style: TextStyle(
                    color: textColor,
                  ), // Color del texto ingresado
                  decoration: InputDecoration(
                    labelText: 'PIN',
                    labelStyle: TextStyle(color: hintColor), // Color del label
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: hintColor.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: primaryColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: Icon(
                      Icons.lock_outline,
                      color: hintColor,
                    ), // Icono de candado
                    filled: true,
                    fillColor: Colors.grey.shade900.withOpacity(0.7),
                  ),
                  obscureText: true,
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 30), // Espacio ajustado
                ElevatedButton.icon(
                  icon:
                      _isLoading
                          ? SizedBox(
                            // Indicador de carga estilizado
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                textColor,
                              ),
                            ),
                          )
                          : Icon(Icons.login, color: textColor),
                  label: Text(
                    _isLoading ? 'Ingresando...' : 'Iniciar Sesión',
                    style: TextStyle(fontSize: 16, color: textColor),
                  ),
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        primaryColor, // Color de fondo del botón (rojo)
                    minimumSize: Size(double.infinity, 50), // Tamaño del botón
                    padding: EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      // Bordes redondeados
                      borderRadius: BorderRadius.circular(8),
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

  Future<void> _login() async {
    // Oculta el teclado si está abierto
    FocusScope.of(context).unfocus();

    if (_phoneController.text.isEmpty || _pinController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor completa todos los campos'),
          backgroundColor: Colors.orange.shade800, // Color para advertencias
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.login(_phoneController.text, _pinController.text);
      // La navegación ocurrirá automáticamente si el login es exitoso
      // gracias al StreamBuilder en main.dart (o donde sea que manejes el estado auth)
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al iniciar sesión: ${e.toString()}'),
          backgroundColor: Colors.red.shade800, // Color para errores
        ),
      );
    } finally {
      // Asegúrate de que el widget todavía está montado antes de llamar a setState
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }
}
