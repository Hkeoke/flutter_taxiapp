import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:flutter/services.dart'; // Para input formatters
import '../services/api.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CreateOperatorScreen extends StatefulWidget {
  const CreateOperatorScreen({Key? key}) : super(key: key);

  @override
  _CreateOperatorScreenState createState() => _CreateOperatorScreenState();
}

class _CreateOperatorScreenState extends State<CreateOperatorScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  // Controladores
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  // Estado del formulario
  bool _obscurePin = true; // Para ocultar/mostrar PIN

  // Define colores para consistencia (iguales a CreateDriverScreen)
  final Color primaryColor = Colors.red;
  final Color scaffoldBackgroundColor = Colors.grey.shade100;
  final Color cardBackgroundColor = Colors.white;
  final Color textColorPrimary = Colors.black87;
  final Color textColorSecondary = Colors.grey.shade600;
  final Color iconColor = Colors.red; // Iconos principales rojos
  final Color inputIconColor = Colors.grey.shade500; // Iconos dentro de inputs
  final Color errorColor = Colors.red.shade700;
  final Color successColor = Colors.green.shade600;
  final Color buttonTextColor = Colors.white;
  final Color borderColor = Colors.grey.shade300;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneNumberController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    // Ocultar teclado
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Por favor corrija los errores en el formulario'),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      // Llamar al servicio para crear el operador
      final authService = AuthService();
      final operatorService = OperatorService();

      // Primero registrar el usuario
      // Asegúrate que los nombres de campo coincidan con tu backend/Supabase
      final userData = {
        'phone_number': _phoneNumberController.text.trim(),
        'pin': _pinController.text.trim(),
        'role': 'operador', // Asegúrate que este rol exista en tu sistema
        'active': true,
      };

      final user = await authService.register(userData);

      // Luego crear el perfil de operador
      // Asegúrate que los nombres de campo coincidan con tu backend/Supabase
      final profileData = {
        'id': user.id, // Usar el ID del usuario recién creado
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        // 'identity_card' parece no tener un campo en el form, ¿es necesario?
        // Si no, puedes quitarlo o añadir un campo si hace falta.
        // 'identity_card': 'ID-${DateTime.now().millisecondsSinceEpoch}',
      };

      await operatorService.createProfile(profileData);

      if (!mounted) return; // Verificar si el widget sigue montado

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Operador creado correctamente'),
          backgroundColor: successColor,
        ),
      );
      Navigator.pop(context, true); // Volver con resultado exitoso
    } catch (error) {
      developer.log('Error en handleSubmit: $error');
      if (mounted) {
        // Verificar si el widget sigue montado
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            // Mostrar un error más específico si es posible
            content: Text('Error al crear operador: ${error.toString()}'),
            backgroundColor: errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        // Verificar si el widget sigue montado
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cardBackgroundColor,
        foregroundColor: textColorPrimary,
        elevation: 1.0,
        title: const Text(
          'Crear Nuevo Operador', // Título más descriptivo
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: iconColor), // Icono rojo
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0), // Padding consistente
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start, // Alineación estándar
              children: [
                // Encabezado (Opcional, ya está en AppBar)
                // Padding(
                //   padding: const EdgeInsets.only(bottom: 20.0),
                //   child: Text(
                //     'Ingrese los datos del nuevo operador',
                //     style: TextStyle(fontSize: 16, color: textColorSecondary),
                //   ),
                // ),

                // --- Campos del Formulario ---
                _buildSectionTitle('Información Personal'), // Título de sección
                _buildInputField(
                  label: 'Nombre(s)',
                  controller: _firstNameController,
                  icon: LucideIcons.user,
                  placeholder: 'Ingrese el nombre',
                  validator:
                      (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'El nombre es obligatorio'
                              : null,
                  textCapitalization: TextCapitalization.words,
                ),
                _buildInputField(
                  label: 'Apellidos',
                  controller: _lastNameController,
                  icon: LucideIcons.userCheck, // Icono diferente
                  placeholder: 'Ingrese los apellidos',
                  validator:
                      (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Los apellidos son obligatorios'
                              : null,
                  textCapitalization: TextCapitalization.words,
                ),

                const SizedBox(height: 16),
                _buildSectionTitle(
                  'Información de Acceso',
                ), // Título de sección
                _buildInputField(
                  label: 'Teléfono',
                  controller: _phoneNumberController,
                  icon: LucideIcons.phone,
                  placeholder: 'Ingrese el número de teléfono',
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El teléfono es obligatorio';
                    }
                    if (value.length < 8) {
                      // Validación simple de longitud
                      return 'Ingrese un número de teléfono válido';
                    }
                    return null;
                  },
                ),
                _buildInputField(
                  label: 'PIN de Acceso',
                  controller: _pinController,
                  icon: LucideIcons.keyRound, // Icono diferente
                  placeholder: 'PIN de 4 a 6 dígitos',
                  keyboardType: TextInputType.number,
                  obscureText: _obscurePin,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  suffixIcon: IconButton(
                    // Icono para mostrar/ocultar PIN
                    icon: Icon(
                      _obscurePin ? LucideIcons.eyeOff : LucideIcons.eye,
                      color: textColorSecondary,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePin = !_obscurePin;
                      });
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El PIN es obligatorio';
                    }
                    if (value.length < 4) {
                      return 'El PIN debe tener al menos 4 dígitos';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24), // Espacio antes del botón
                // --- Botón de envío ---
                _buildSubmitButton(), // Usar widget reutilizable
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -- Widgets Reutilizables de Construcción -- (Idénticos a CreateDriverScreen)

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textColorPrimary.withOpacity(0.8),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String placeholder,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    int? maxLength,
    String? Function(String?)? validator,
    Widget? suffixIcon,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0), // Espaciado entre campos
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: textColorSecondary),
          hintText: placeholder,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(icon, color: inputIconColor, size: 20),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: cardBackgroundColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: primaryColor, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: errorColor, width: 1.0),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: errorColor, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 12,
          ),
          counterText: '', // Ocultar contador de maxLength por defecto
        ),
        keyboardType: keyboardType,
        obscureText: obscureText,
        maxLength: maxLength,
        validator: validator,
        inputFormatters: inputFormatters,
        textCapitalization: textCapitalization,
        style: TextStyle(fontSize: 15, color: textColorPrimary),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon:
            _loading
                ? Container() // No mostrar icono si está cargando
                // Usar un icono relevante para crear operador
                : Icon(LucideIcons.userCog, size: 18, color: buttonTextColor),
        label:
            _loading
                ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: buttonTextColor,
                    strokeWidth: 2.5,
                  ),
                )
                : Text(
                  'Crear Operador', // Texto del botón
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: buttonTextColor,
                  ),
                ),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: buttonTextColor, // Color del ripple
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 2, // Sombra sutil
        ),
        onPressed: _loading ? null : _handleSubmit,
      ),
    );
  }
}
